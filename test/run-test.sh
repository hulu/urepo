#!/bin/bash

set -u -e

script_dir=$(cd "$(dirname $0)" && pwd)
test_binary="${script_dir}/../extract-post-file"
test_run_dir=/tmp/tmp-$$

tests_passed=0
tests_failed=0

mkdir -p $test_run_dir

for test_dir in $script_dir/[0-9]*-test; do
    test_name=$(basename ${test_dir})
    mkdir -p ${test_run_dir}/${test_name}/files
    cp $test_dir/stdin ${test_run_dir}/${test_name}
    ( cd ${test_run_dir}/${test_name}/files && $test_binary < ../stdin > ../stdout 2> ../stderr )
    if diff -r ${test_run_dir}/${test_name} $test_dir ; then
        echo "$test_name ok"
        ((tests_passed++)) || true
    else
        echo "$test_name failed"
        ((tests_failed++)) || true
    fi
done

rm -rf $test_run_dir
echo "Summary: $tests_passed tests passed, $tests_failed tests failed"
((tests_failed != 0)) && exit 1
exit 0
