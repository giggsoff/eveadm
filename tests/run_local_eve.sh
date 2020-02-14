#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi
eve_repo=https://github.com/itmo-eve/eve.git
memory_to_use=4096
while [ -n "$1" ]
do
case "$1" in
-m) memory_to_use="$2"
echo "Use with memory $memory_to_use"
shift ;;
--) shift
break ;;
*) echo "$1 is not an option";;
esac
shift
done
tmp_dir=$(mktemp -d -t eveadam-"$(date +%Y-%m-%d-%H-%M-%S)"-XXXXXXXXXX)
ssh_port=`comm -23 <(seq 49252 49352 | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1`
echo ========================================
echo "Temp directory for test: $tmp_dir"
echo ========================================
eve_dir="$tmp_dir"/eve
apt update
apt upgrade -y
snap install --classic go
apt-get install -y git make docker.io qemu-system-x86 qemu-utils openssl jq
touch ~/.rnd
cd "$tmp_dir" || exit
git clone $eve_repo
echo ========================================
echo "Generate keypair for ssh (no overwrite if exists)"
echo ========================================
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N "" <<< n
echo
echo ========================================
echo "Prepare and run EVE"
echo ========================================
cd $eve_dir||exit
cd conf||exit
yes | cp -f /root/.ssh/id_rsa.pub authorized_keys
onboarduuid=$(uuidgen)
sn=$(head -200 /dev/urandom | cksum | cut -f1 -d " "|fold -w 8|head -n 1)
openssl ecparam -name prime256v1 -genkey -noout -out onboard.key.pem
openssl req -x509 -new -nodes -key onboard.key.pem -sha256 -subj "/C=RU/ST=SPB/O=MyOrg, Inc./CN=$onboarduuid" -days 1024 -out onboard.cert.pem
cd $eve_dir||exit
sed -i "s/SandyBridge/host/g" Makefile
sed -i "s/31415926/$sn/g" Makefile
sed -i "s/-m 4096/-m $memory_to_use/g" Makefile
make live
nohup make ACCEL=true SSH_PORT=$ssh_port run >$tmp_dir/eve.log 2>&1 &
echo $! >../eve.pid
echo ========================================
echo "EVE pid:"
cat ../eve.pid
echo ========================================
echo "EVE config successfull"
echo ========================================
echo "Please use Onboarding Key"
echo "$onboarduuid"
echo "and Serial Number"
echo "$sn"
echo "in zedcloud.zededa.net"
echo "You can connect to node via ssh"
echo "sudo ssh -p $ssh_port 127.0.0.1"
while true; do
    read -p "Do you want to cleanup? (y/n)" yn
    case $yn in
        [Yy]* )
          kill `cat $tmp_dir/eve.pid`
          sleep 5
          rm -rf $tmp_dir ; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
