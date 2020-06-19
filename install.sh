#!/bin/sh

if [ ! -x "$(command -v sudo)" ]
then
  alias sudo=""
  echo "WARNING: sudo disabled!"
fi


echo Checking for kali repos
sudo apt-get update

# We need this to add repos
sudo apt-get install gpg -y
sudo mkdir -p /etc/apt/sources.list.d/

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

if [ -z $IS_KALI ] && [ -z "$(apt-cache policy | grep metasploit)" ]
then
  echo "Adding Metasploit repo"
  echo deb https://apt.metasploit.com/ lucid main | sudo tee /etc/apt/sources.list.d/metasploit-framework.list > /dev/null
  curl https://apt.metasploit.com/metasploit-framework.gpg.key | sudo apt-key add
  sudo apt-get update
fi


EXPECTED_TOOLS=
BASE_INSTALL=
KALI_INSTALL=
PIP_INSTALL=

check_base() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then BASE_INSTALL="$2 $BASE_INSTALL"; fi
}

check_kali() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then KALI_INSTALL="$2 $KALI_INSTALL"; fi
}

check_pip() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then PIP_INSTALL="$2 $PIP_INSTALL"; fi
}

check_cmd() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]
  then
    sudo tee "/usr/local/bin/$1" > /dev/null << EOF
#!/bin/sh
$2
EOF
    sudo chmod +x "/usr/local/bin/$1"
fi
}

check_docker() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]
  then
    docker pull $2
    check_cmd $1 "docker run -it $1 -- \$@"
  fi
}

clone_source() {
  mkdir -p ~/.c3-ctf
  SRC_BASE_DIR="$HOME/.c3-ctf/$1"
  if [ -d "$SRC_BASE_DIR" ]
  then
    cd $SRC_BASE_DIR
    git remote set-url origin "$2"
    git fetch --depth 1
    git reset --hard origin/master
  else
    git clone $2 --depth 1 "$SRC_BASE_DIR"
    cd $SRC_BASE_DIR
  fi
}

# Some core components
check_base cmake cmake
check_base gcc gcc
check_base g++ g++
check_base git git
check_base make build-essential
check_base docker-ce
check_base python3-pip

# Nice stuff
check_base nano nano
check_base tor tor
check_base torbrowser-launcher torbrowser-launcher

# Toolz
check_base nmap nmap
check_base openvpn openvpn
check_base wfuzz wfuzz

check_kali hashcat hashcat
check_kali wordlists wordlists
check_kali john john # Debian main has it, but it is the old version (as usual!)
check_kali steghide steghide

if [ -z $IS_KALI]; then check_base msfconsole metasploit-framework; fi

if [ ! -z "$BASE_INSTALL$KALI_INSTALL" ]
then
  echo "You are missing some packages: $BASE_INSTALL$KALI_INSTALL"
  sudo apt-get install $BASE_INSTALL -y
  sudo apt-get install $KALI_INSTALL -y -t kali-rolling
fi
if [ ! -z "$PIP_INSTALL" ]
then
  echo "You are missing some python packages"
  sudo python3 -m pip install $PIP_INSTALL
fi

# clone_source and check_docker need to be done *after* docker and git are instaleld
clone_source sherlock https://github.com/sherlock-project/sherlock
pip3 install -r "$SRC_BASE_DIR/requirements.txt"
check_cmd sherlock "python3 $SRC_BASE_DIR/sherlock \$@"

echo "You now have up-to-date versions of:"
echo "        $EXPECTED_TOOLS"
