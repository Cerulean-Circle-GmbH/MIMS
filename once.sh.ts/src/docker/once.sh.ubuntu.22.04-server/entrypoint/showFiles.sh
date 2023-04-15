#!/bin/bash

find /var/dev /var/nix /home /root -exec ls -lad {} \; || true