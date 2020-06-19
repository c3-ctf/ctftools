#!/bin/sh

echo Checking for kali repos
sudo apt-get update

# We need this to add repos
sudo apt-get install gpg -y
sudo mkdir -p /etc/apt/sources.list.d/

if [ ! -x "$(command -v sudo)" ]
then
  alias sudo=""
  echo "WARNING: sudo disabled!"
fi

if [ -z "$(apt-cache policy | grep kali-rolling)" ]
then
  echo Adding kali repos

  echo deb https://archive-4.kali.org/kali kali-rolling main contrib non-free | sudo tee /etc/apt/sources.list.d/kali.list > /dev/null
  # This means that you have to manually select the packages
  cat << 'EOF' | sudo tee /etc/apt/preferences > /dev/null
Package: *
Pin: release o=kali
Pin-Priority: -10
EOF
  # Add the key
  curl https://archive.kali.org/archive-key.asc | sudo apt-key add
  sudo apt-get update
fi

IS_KALI=
if [ ! -z "$(cat /etc/*release | grep -i kali)" ]
then
  IS_KALI="yes"
fi

EXPECTED_TOOLS=
BASE_INSTALL=
KALI_INSTALL=

check_base() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then TO_INSTALL="$2 $BASE_INSTALL"; fi
}

check_kali() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then TO_INSTALL="$2 $KALI_INSTALL"; fi
}

check_base openvpn openvpn

check_kali wfuzz wfuzz
check_kali hashcat hashcat
check_kali wordlists wordlists

if [ -z $IS_KALI ] && [ -z "$(apt-cache policy | grep metasploit-framework)" ]
then
  echo "Adding Metasploit repo"
  echo deb https://apt.metasploit.com/ lucid main | sudo tee /etc/apt/sources.list.d/metasploit-framework.list > /dev/null
  curl https://apt.metasploit.com/metasploit-framework.gpg.key | sudo apt-key add
  sudo apt-get update
  check_base metasploit-framework
fi


if [ ! -z "$BASE_INSTALL$KALI_INSTALL" ]
then
  echo "You are missing some packages: $BASE_INSTALL$KALI_INSTALL"
  sudo apt-get install $BASE_INSTALL -y
  sudo apt-get install $KALI_INSTALL -y -t kali-rolling
fi

echo "You now have up-to-date versions of:"
echo "        $EXPECTED_TOOLS"
