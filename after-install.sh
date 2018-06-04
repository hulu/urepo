#!/bin/bash

[ -f /etc/urepo/urepo.conf ] || cp /usr/share/urepo/urepo.conf.example /etc/urepo/urepo.conf
/etc/urepo/urepo-config.sh
