#!/bin/bash

[[ -f ~/.bashrc ]] && . ~/.bashrc

sudo /usr/local/bin/init-firewall.sh || { printf "firewall init failed\n" ; exit 1; }

cd /workspace
