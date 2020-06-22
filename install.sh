#!/bin/sh

if [ ! -x "$(command -v sudo)" ]
then
  SUDO=""
  echo "WARNING: sudo disabled!"
else
  SUDO="sudo"
fi

echo "Updating repos"
$SUDO apt-get -qq update
$SUDO apt-get -q upgrade -y

# We need this to add repos
$SUDO apt-get -qq install gpg lsb-release -y
$SUDO mkdir -p /etc/apt/sources.list.d/

echo Checking for kali repos
if [ -z "$(apt-cache policy | grep kali-rolling)" ]
then
  echo "Adding Kali repos"

  echo deb https://archive-4.kali.org/kali kali-rolling main contrib non-free | $SUDO tee /etc/apt/sources.list.d/kali.list > /dev/null
  # This means that you have to manually select the packages
  cat << 'EOF' | $SUDO tee /etc/apt/preferences > /dev/null
Package: *
Pin: release o=kali
Pin-Priority: -10
EOF
  # Add the key
  curl -s https://archive.kali.org/archive-key.asc | $SUDO apt-key add > /dev/null 2>/dev/null
  $SUDO apt-get update > /dev/null
else
  echo "Kali repos found"
fi

IS_KALI=
if [ ! -z "$(cat /etc/*release | grep -i kali)" ]
then
  IS_KALI="yes"
fi

if [ ! -z $IS_KALI ]; then OS_NAME="debian"; OS_RELEASE="sid"; else OS_NAME="$(lsb_release -is | awk '{print tolower($0)}')"; OS_RELEASE="$(lsb_release -cs)"; fi

if [ -z $IS_KALI ] && [ -z "$(apt-cache policy | grep metasploit)" ]
then
  echo "Adding Metasploit repo"
  echo "deb https://apt.metasploit.com/ lucid main" | $SUDO tee /etc/apt/sources.list.d/metasploit-framework.list > /dev/null
  curl -s https://apt.metasploit.com/metasploit-framework.gpg.key | $SUDO apt-key add > /dev/null 2>/dev/null
  $SUDO apt-get update > /dev/null
fi

if [ -z "$(apt-cache policy | grep docker)" ]
then
  if [ "$OS_RELEASE" = "sid" ]; then DOCKER_RELEASE="buster"; else DOCKER_RELEASE="$OS_RELEASE"; fi
  echo "Installing Docker repo"
  curl -s -fsSL https://download.docker.com/linux/debian/gpg | $SUDO apt-key add - > /dev/null 2>/dev/null
  echo "deb [arch=amd64] https://download.docker.com/linux/$OS_NAME $DOCKER_RELEASE stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  $SUDO apt-get update > /dev/null
fi


EXPECTED_TOOLS=
BASE_INSTALL=
BACK_INSTALL=
KALI_INSTALL=
BACKPORT_INSTALL=
PIP_INSTALL=

check_base() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ] && ! dpkg -l $2 > /dev/null 2> /dev/null
  then
    BASE_INSTALL="$2 $BASE_INSTALL"
  fi
}

check_back() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ] && ! dpkg -l $2 > /dev/null 2> /dev/null
  then
    BACK_INSTALL="$2 $BACK_INSTALL"
  fi
}

check_kali() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ] && ! dpkg -l $2 > /dev/null 2> /dev/null
  then
    KALI_INSTALL="$2 $KALI_INSTALL"
  fi
}

check_pip() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]; then PIP_INSTALL="$2 $PIP_INSTALL"; fi
}

check_cmd() {
  EXPECTED_TOOLS="$1 $EXPECTED_TOOLS"
  if [ ! -x "$(command -v $1)" ]
  then
    $SUDO tee "/usr/local/bin/$1" > /dev/null << EOF
#!/bin/sh
$2
EOF
    $SUDO chmod +x "/usr/local/bin/$1"
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
check_base docker docker-ce
check_base pip3 python3-pip
check_base jq jq

# Nice stuff
check_base nano nano
check_base tor tor
check_back torbrowser-launcher torbrowser-launcher

# Toolz
check_base nmap nmap
check_base openvpn openvpn
check_base wfuzz wfuzz

check_kali hashcat hashcat
check_kali wordlists wordlists
check_kali seclists seclists
check_kali john john # Debian main has it, but it is the old version (as usual!)
check_kali steghide steghide

if [ -z $IS_KALI ]; then check_base msfconsole metasploit-framework; fi

if [ ! -z "$BACK_INSTALL" ]
then
  case "$OS_RELEASE" in
  stretch)
    echo "Adding stretch backports"
    BACK_OPTS="-t stretch-backports"
    cat < 'EOF' | $SUDO tee /etc/apt/sources.list.d/stretch-backports.list > /dev/null
deb http://deb.debian.org/debian stretch-backports main contrib
deb http://deb.debian.org/debian stretch-backports-sloppy main contrib
EOF
    $SUDO apt-get update
    ;;
  buster)
    echo "Adding buster backports"
    BACK_OPTS="-t buster-backports"
    echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" | $SUDO tee /etc/apt/sources.list.d/buster-backports.list
    $SUDO apt-get update
    ;;
  *)
    BASE_INSTALL="$BASE_INSTALL $BACK_INSTALL"
    ;;
  esac
fi

if [ ! -z "$BASE_INSTALL" ]
then
  echo "Installing missing base packages $BASE_INSTALL"
  # Remove docker from debian base repos in install
  $SUDO apt-get -qq install $BASE_INSTALL docker.io- -y
fi

if [ ! -z "$BACK_OPTS" ]
then
  echo "Installing missing backports packages $BACK_INSTALL"
  apt-get -qq install $BACK_INSTALL $BACK_OPTS
fi

if [ ! -z "$KALI_INSTALL" ]
then
  echo "Installing missing Kali packages: $KALI_INSTALL"
  $SUDO apt-get -qq install $KALI_INSTALL -y -t kali-rolling
fi

# Pip ins needed
check_pip shodan shodan

if [ ! -z "$PIP_INSTALL" ]
then
  echo "You are missing some python packages"
  $SUDO python3 -m pip -qqq install $PIP_INSTALL
fi

# clone_source and check_docker need to be done *after* docker and git are instaleld
echo "Updating sherlock"
clone_source sherlock https://github.com/sherlock-project/sherlock
python3 -m pip install -qqq -r "$SRC_BASE_DIR/requirements.txt"
check_cmd sherlock "python3 $SRC_BASE_DIR/sherlock \$@"

# jq is needed
EXPECTED_TOOLS="cutter $EXPECTED_TOOLS"
target=$(mktemp)
# For some reason, dash keeps putting \r at the end of X=$()
curl -s https://api.github.com/repos/radareorg/cutter/releases/latest -o "$target"
if [ -x "$(command -v cutter)" ] && [ "\"$(cutter -v)\"" = "$(cat $target | jq .name)" ] # jq puts quotes on things, so we need extra quotes
then
  echo "Cutter already up to date!"
else
  echo "Installing Cutter"
  cat "$target" | jq '.assets | .[] | .browser_download_url' | grep AppImage | xargs $SUDO curl -s -L -o /usr/local/bin/cutter
  $SUDO chmod +x /usr/local/bin/cutter
fi
rm "$target"

echo "You now have up-to-date versions of:"
echo "        $EXPECTED_TOOLS"

curl -s https://raw.githubusercontent.com/c3-ctf/ctftools/master/TOOLS
