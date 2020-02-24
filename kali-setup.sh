#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo Installing kali repos
echo deb https://archive-4.kali.org/kali kali-last-snapshot main contrib non-free > /etc/apt/sources.list.d/kali.list

echo Package: *
echo Pin: release o=kali
Pin-Priority: -10


echo Updating apt
apt-get update

echo Installing packages
apt-get install -y -t kali-last-snapshot
apt-get install -y john dirb steghide exiftool
