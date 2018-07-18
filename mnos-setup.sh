#!/bin/bash

#  ███╗   ███╗███╗   ██╗ ██████╗ ███████╗
#  ████╗ ████║████╗  ██║██╔═══██╗██╔════╝
#  ██╔████╔██║██╔██╗ ██║██║   ██║███████╗
#  ██║╚██╔╝██║██║╚██╗██║██║   ██║╚════██║
#  ██║ ╚═╝ ██║██║ ╚████║╚██████╔╝███████║
#  ╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
#                                     
#  An automated shell script to set up MNOS Masternodes
#  ====================================================
#  @version: v1.0.0.0
#  @author: MNOS Dev Team
#  @email: contact@mnos.io
#  @website: https://mnos.io


TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="mnos.conf"
CONFIG_FOLDER=".mnos"
WALLET_HEADLESS_FILE="/usr/local/bin/mnosd"
WALLET_CLI_FILE="/usr/local/bin/mnos-cli"
MNOS_REPO="https://github.com/MNOSIO/mnos.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function show_banner() {
echo "$(tput bold)$(tput setaf 4)=============  Welcome to the MNOS Masternode Setup Script  ===============$(tput setaf 4)"
cat << "EOF"
███╗   ███╗███╗   ██╗ ██████╗ ███████╗
████╗ ████║████╗  ██║██╔═══██╗██╔════╝
██╔████╔██║██╔██╗ ██║██║   ██║███████╗
██║╚██╔╝██║██║╚██╗██║██║   ██║╚════██║
██║ ╚═╝ ██║██║ ╚████║╚██████╔╝███████║
╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
EOF
echo "$(tput bold)$(tput setaf 4)"
echo "$(tput setaf 4)Official Website: https://mnos.io$(tput sgr0)"
echo "$(tput sgr0)$(tput bold)$(tput setaf 4)The most powerful infrastructure for Masternode Ecosystem. $(tput sgr0)"
echo "$(tput setaf 4)===========================================================================$(tput sgr0)"
}

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
# check system
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}Installation Cancelled: $0 requires Ubuntu 16.04.${NC}"
  exit 1
fi

#check user
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

#check mnosd
if [ -n "$(pidof mnosd)" ]; then
  echo -e "${GREEN}\c"
  read -e -p "mnosd is already running. Do you want to setup another Masternode? [Y/N]" NEW_MNOS
  echo -e "{NC}"
  clear
else
  NEW_MNOS="new"
fi
}

function prepare_system() {

echo -e "Prepare the environment to setup MNOS masternode ..."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update -y >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libevent-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev pkg-config \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils \
libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pwgen
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update -y"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update -y"
    echo "apt install -y make build-essential libtool autoconf libssl-dev libevent-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev pkg-config \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw"
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(swapon -s)
if [[ "$PHYMEM" -lt "2" && -z "$SWAP" ]];
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM, creating 2G swap file.${NC}"
    dd if=/dev/zero of=/swapfile bs=1024 count=2M
    chmod 600 /swapfile
    mkswap /swapfile
    swapon -a /swapfile
else
  echo -e "${GREEN}The server running with at least 2G of RAM, or SWAP exists.${NC}"
fi
clear
}

function ask_firewall() {
 echo -e "${RED}I want to protect this server with a firewall and limit connexion to SSH and MNOS.${NC}."
 echo -e "Please type ${GREEN}YES${NC} if you want to enable the firewall, or type anything else to skip"
 read -e UFW
}

function compile_mnos() {
  echo -e "Clone git repo and compile it. This may take some time. Press any key to continue."
  read -n 1 -s -r -p ""

  git clone $MNOS_REPO $TMP_FOLDER
  cd $TMP_FOLDER
  git checkout rebrand
  ./autogen.sh
  ./configure --disable-tests --without-gui
  make
  compile_error MNOS
  cp -a src/mnosd $WALLET_HEADLESS_FILE
  cp -a src/mnos-cli $WALLET_CLI_FILE
  clear
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow incomning access on port ${GREEN}$MNOSPORT${NC}"
  ufw allow $MNOSPORT/tcp comment "MNOS P2P port" >/dev/null
  ufw allow $[MNOSPORT+1]/tcp comment "MNOS RPC port" >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function systemd_mnos() {
  cat << EOF > /etc/systemd/system/$MNOSUSER.service
[Unit]
Description=MNOS service
After=network.target

[Service]

Type=forking
User=$MNOSUSER
Group=$MNOSUSER
WorkingDirectory=$MNOSHOME
ExecStart=$WALLET_HEADLESS_FILE -daemon
ExecStop=$WALLET_CLI_FILE stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $MNOSUSER.service
  systemctl enable $MNOSUSER.service >/dev/null 2>&1

  if [[ -z $(pidof mnosd) ]]; then
    echo -e "${RED}mnosd is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo "systemctl start $MNOSUSER.service"
    echo "systemctl status $MNOSUSER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function ask_port() {
DEFAULTMNOSPORT=6555
read -p "MNOS P2P Port: " -i $DEFAULTMNOSPORT -e MNOSPORT
: ${MNOSPORT:=$DEFAULTMNOSPORT}
}

function ask_user() {
  DEFAULTMNOSUSER="mnos"
  read -p "MNOS user: " -i $DEFAULTMNOSUSER -e MNOSUSER
  : ${MNOSUSER:=$DEFAULTMNOSUSER}

  if [ -z "$(getent passwd $MNOSUSER)" ]; then
    useradd -m $MNOSUSER
    USERPASS=$(pwgen -s 12 1)
    echo "$MNOSUSER:$USERPASS" | chpasswd

    MNOSHOME=$(sudo -H -u $MNOSUSER bash -c 'echo $HOME')
    DEFAULTMNOSFOLDER="$MNOSHOME/.mnos"
    read -p "Configuration folder: " -i $DEFAULTMNOSFOLDER -e MNOSFOLDER
    : ${MNOSFOLDER:=$DEFAULTMNOSFOLDER}
    mkdir -p $MNOSFOLDER
    chown -R $MNOSUSER: $MNOSFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $MNOSPORT ]] || [[ ${PORTS[@]} =~ $[MNOSPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $MNOSFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[MNOSPORT+1]
listen=1
server=1
daemon=1
port=$MNOSPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e MNOSKEY
  if [[ -z "$MNOSKEY" ]]; then
  sudo -u $MNOSUSER /usr/local/bin/mnosd -conf=$MNOSFOLDER/$CONFIG_FILE -datadir=$MNOSFOLDER
  sleep 10
  if [ -z "$(pidof mnosd)" ]; then
   echo -e "${RED}mnosd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  MNOSKEY=$(sudo -u $MNOSUSER $WALLET_CLI_FILE -conf=$MNOSFOLDER/$CONFIG_FILE -datadir=$MNOSFOLDER masternode genkey)
  sudo -u $MNOSUSER $WALLET_CLI_FILE -conf=$MNOSFOLDER/$CONFIG_FILE -datadir=$MNOSFOLDER stop
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $MNOSFOLDER/$CONFIG_FILE
  NODEIP=$(curl -s4 icanhazip.com)
  cat << EOF >> $MNOSFOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
masternode=1
masternodeaddr=$NODEIP:$MNOSPORT
masternodeprivkey=$MNOSKEY
EOF
  chown -R $MNOSUSER: $MNOSFOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Congratulations! MNOS Masternode is up and running as user ${GREEN}$MNOSUSER${NC} and listening on port ${GREEN}$MNOSPORT${NC}."
 echo -e "${GREEN}$MNOSUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$MNOSFOLDER/$CONFIG_FILE${NC}"
 echo -e "=========================================================== Commands ==========================================================="
 echo -e "Start mnosd: ${RED}systemctl start $MNOSUSER.service${NC}"
 echo -e "Stop mnosd: ${RED}systemctl stop $MNOSUSER.service${NC}"
 echo -e "=========================================================== MN Info ============================================================"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$MNOSPORT${NC}"
 echo -e "Masternode PrivateKey: ${RED}$MNOSKEY${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  ask_firewall
  if [[ "$UFW" == "YES" ]]; then
    enable_firewall
  fi  
  systemd_mnos
  important_information
}


##### Main #####
clear
show_banner
checks

if [[ ("$NEW_MNOS" == "y" || "$NEW_MNOS" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_MNOS" == "new" ]]; then
  prepare_system
  compile_mnos
  setup_node
else
  echo -e "${GREEN}MNOS already running.${NC}"
  exit 0
fi