/* 
 * This utility was created because nginx 1.3.9+ doesn't have http upload module any more.
 * This utility is accepting post request on stdin and saves in current directory files
 * from request if any. File data is removed from post request, rest part of post request
 * is piped through unchanged.
 *
 * Author: kirill.timofeev@hulu.com
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <stdarg.h>

// constants for state machine
#define STATE_NONE                  0
#define STATE_BOUNDARY_FOUND        1
#define STATE_FILE_OPENED           2
#define STATE_CONTENT_TYPE_FOUND    3
#define STATE_EMPTY_LINE_FOUND      4
#define STATE_WRITE_TO_FILE         5

// strlen definition that can be used with defined strings
#define STRLEN(s) (sizeof(s) / sizeof(s[0]) - 1)

// strings we want to recognise in the input stream
#define CONTENT_DISPOSITION_STR "Content-Disposition: form-data; "
#define CONTENT_TYPE_STR        "Content-Type:"
#define EMPTY_LINE_STR          "\r\n"
#define FILENAME_STR            "filename=\""

#define CONTENT_DISPOSITION_LEN STRLEN(CONTENT_DISPOSITION_STR)
#define CONTENT_TYPE_LEN        STRLEN(CONTENT_TYPE_STR)
#define EMPTY_LINE_LEN          STRLEN(EMPTY_LINE_STR)
#define FILENAME_LEN            STRLEN(FILENAME_STR)

// boundary string is stored in separate buffer
// this is 1st line of the input stream
#define BOUNDARY_BUF_SIZE 128
char boundary_buf[BOUNDARY_BUF_SIZE];
int boundary_len = 0;

// buffer used while reading rest of input stream
#define DATA_BUF_SIZE 8192

// perl like die() function
void die(const char * format, ...) {
    va_list vargs;

    va_start(vargs, format);
    vfprintf(stderr, format, vargs);
    exit(1);
}

// This function processes end of Content-Disposition string
// It tries to locate filename, strips path if any and openes
// file in exclusive write mode in current directory.
// Returns FILE * in case of success, NULL if Content-Disposition
// string has no filename
FILE *open_file(char *buf, int length) {
    char *file_name = NULL;     // pointer to filename
    char *file_name_eos = NULL; // pointer to end of string with filename
    char *c = NULL;             // temporary pointer
    FILE *out_file = NULL;      // FILE * pointer that would be returned in case of success
    char t = 0;                 // temporary value

    // scanning string
    for (file_name = buf; file_name < buf + length - FILENAME_LEN; file_name++) {
        if (memcmp(file_name, FILENAME_STR, FILENAME_LEN) != 0) {
            continue; // filename not found, let's go to next loop iteration
        }
        // filename located, let's adjust pointer to point to start of filename string
        file_name += FILENAME_LEN;
        // let's locate end of filename string
        // TODO we are looking for terminating quote
        // TODO this means filename can't have embedded quotes
        // TODO not a huge deal for now, but let's not forget about this
        file_name_eos = memchr(file_name, '"', length - (file_name - buf));
        // if terminating quote wasn't found something is wrong
        if (file_name_eos == NULL) {
            die("Malformed filename in \"%.*s\" string\n", length, buf);
        }
        // now let's scan filename starting with end and strip off path if any
        for (c = file_name_eos - 1; c > file_name; c--) {
            if (*c == '\\' || *c == '/') {
                file_name = c + 1;
                break;
            }
        }
        // in order to open file we need 0 terminated string
        // so let's save char beyond filename end
        t = *file_name_eos;
        // substitute it with 0
        *file_name_eos = 0;
        // open file and check if we are good
        out_file = fopen(file_name, "wx");
        if (out_file == NULL) {
            die("Failed to open file %s for writing\n", file_name);
        }
        // restore char since this would be printed
        *file_name_eos = t;
        return out_file;
    }
    return NULL;
}

// this function processes chunk of data read from stdout
// if this could be line from post request (delimited by newlines)
// we use parse_string flag to look for post strings in the line
void process_data(char *buf, int length, int parse_string) {
    static int state = STATE_NONE; // parser state
    static FILE *out_file = NULL;  // can be stdout or post_file
    static FILE *post_file = NULL; // file to be saved
    static long file_size = 0;     // file size, need this to truncate file after save

    // TODO can't init out_file with stdout, may be there is better way than this if
    if (out_file == NULL) {
        out_file = stdout;
    }
    // if buf contains string delimited with newlines let's parse it
    if (parse_string) {
        switch (state) {
            // previous line was boundary, we are looking for Content-Disposition
            case STATE_BOUNDARY_FOUND:
                if (length > CONTENT_DISPOSITION_LEN && memcmp(buf, CONTENT_DISPOSITION_STR, CONTENT_DISPOSITION_LEN) == 0) {
                    // if found - let's try to find filename
                    post_file = open_file(buf + CONTENT_DISPOSITION_LEN, length - CONTENT_DISPOSITION_LEN);
                    // if filename was found and file opened successfully - state is advanced
                    if (post_file != NULL) {
                        state = STATE_FILE_OPENED;
                        break;
                    }
                }
                // filename wasn't found, state is reset
                state = STATE_NONE;
                break;
            // previous line was Content-Disposition, next line should be Content-Type
            case STATE_FILE_OPENED:
                if (length > CONTENT_TYPE_LEN && memcmp(buf, CONTENT_TYPE_STR, CONTENT_TYPE_LEN) == 0) {
                    state = STATE_CONTENT_TYPE_FOUND;
                    break;
                }
                // if Content-Type is not found something is wrong
                die("Content type not found\n");
            // previous line was Content-Type, next line should be empty
            case STATE_CONTENT_TYPE_FOUND:
                if (length == EMPTY_LINE_LEN && memcmp(buf, EMPTY_LINE_STR, EMPTY_LINE_LEN) == 0) {
                    state = STATE_EMPTY_LINE_FOUND;
                    break;
                }
                die("Empty line not found\n");
            // now we are ready to save file
            case STATE_EMPTY_LINE_FOUND:
                // switching to appropriate state
                state = STATE_WRITE_TO_FILE;
                // out file is now set to file on disk instead of stdout
                out_file = post_file;
                // file size is reset
                file_size = 0;
                break;
            // we get here from 2 states: STATE_NONE and STATE_WRITE_TO_FILE
            default:
                // if boundary was found
                if (length > boundary_len && memcmp(buf, boundary_buf, boundary_len) == 0) {
                    // and we were writing to the file
                    if (state == STATE_WRITE_TO_FILE) {
                        // let's flush file buffers
                        if (fflush(out_file) != 0) {
                            die("fflush() failed: %s\n", strerror(errno));
                        }
                        // truncate file since last to bytes are 0a 0d from post request
                        if (ftruncate(fileno(out_file), file_size - 2) != 0) {
                            die("ftruncate() failed: %s\n", strerror(errno));
                        }
                        // and close file
                        if (fclose(out_file) != 0) {
                            die("fclose() failed: %s\n", strerror(errno));
                        }
                        // now let's switch back to stdout for output
                        post_file = NULL;
                        out_file = stdout;
                    }
                    // and set appropriate state
                    state = STATE_BOUNDARY_FOUND;
                }
        }
    }
    file_size += length;
    fwrite(buf, sizeof(char), length, out_file);
}

// program entry point
int main(int argc, const char* argv[]) {
    char data_buf[DATA_BUF_SIZE]; // buffer to read data
    int data_len = 0;             // how much unprocessed data we have in buffer
    char *newline_ptr = NULL;     // pointer to newline
    char *data_ptr = data_buf;    // pointer to start of unprocessed data
    int line_len = 0;             // length of the line (if found) delimited by newlines
    int line_start = 1;           // flag: if delimiting newline is present at start of the line
    int line_end = 0;             // flag: if delimiting newline is present in the end of the line
    char *c = NULL;               // temporary pointer

    // 1st line is boundary
    if (fgets(boundary_buf, BOUNDARY_BUF_SIZE, stdin) == NULL) {
        die("Failed to read boundary string\n");
    }
    // let's strip terminating \r\n since final boundary line has additional -- in the end
    c = memchr(boundary_buf, 0, BOUNDARY_BUF_SIZE);
    if (c == NULL) {
        die("Boundary string is not 0-terminated\n");
    }
    for (c -= 1; c > boundary_buf; c--) {
        if (*c != '\r' && *c != '\n') {
            break;
        }
    }
    // let's calculate boundary length
    boundary_len = c - boundary_buf + 1;
    // and output boundary
    fputs(boundary_buf, stdout);
    // main loop until we read all data from stdin
    while (!feof(stdin)) {
        // if while prcessing data in the middle of the buffer we found line starting with newline
        // but we don't see newline in the end it is possible that we have incomplete line
        // so we move all unprocessed data to start of the buffer, read more data into the buffer and try to process it again
        data_len = fread(data_ptr, sizeof(char), DATA_BUF_SIZE - (data_ptr - data_buf), stdin) + (data_ptr - data_buf);
        data_ptr = data_buf;
        // while we have unprocessed data in the buffer
        while (data_len > 0) {
            // let's find delimiting newline in the buffer
            newline_ptr = memchr(data_ptr, '\n', data_len);
            // if newline is not found
            if (newline_ptr == NULL) {
                // and we are in the middle of the buffer
                if (data_ptr != data_buf) {
                    // we move unprocessed data to start of the buffer
                    memmove(data_buf, data_ptr, data_len);
                    // and terminate loop
                    break;
                }
                // if unprocessed data starts from the beginning of the buffer
                // we need to dump it all
                line_len = data_len;
                // and set flag that there is no newline in the end
                line_end = 0;
            } else {
                // if newline was found let's process string delimited by it
                line_len = newline_ptr + 1 - data_ptr;
                line_end = 1;
            }
            // actual data pprocessing
            process_data(data_ptr, line_len, line_start && line_end);
            // we have less data to process
            data_len -= line_len;
            // data_ptr should be advanced
            data_ptr += line_len;
            // flag that line is delimited in the end means that next line is delimited in the beginning
            line_start = line_end;
        }
        // if loop was terminated in the middle data_len is not 0
        data_ptr = data_buf + data_len;
    }
    return 0;
}
