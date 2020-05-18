#!/bin/bash

set -e

print_help() {
echo 'Usage as root or with sudo:
  node_installer 8.9.1 # this installs 8.9.1 version
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help'
}

clean_previous_installations() {
  echo "Cleaning previous node installations"
  rm -rf /usr/local/bin/node
  rm -rf /usr/local/bin/npm
  rm -rf /usr/local/lib/node_modules
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   print_help
   exit 1
fi

if [[ "$1" == 'clean' ]] ; then
  clean_previous_installations
  exit 0
fi

if [[ "$1" == 'help' ]] || [[ -z "$1" ]] ; then
  print_help
  exit 0
fi

if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$1" =~ v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Please provide existing node version in 'x.y.z' or v'x.y.z' format"
  exit 2
fi

if [[ "$1" =~ v[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "node version in v'x.y.z' format"
  NODE="$1"
elif [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "node version in 'x.y.z' format"
  NODE=v"$1"
fi

TARGET=
case $(uname) in
  "Linux")
    TARGET="node-"$NODE"-linux-x64"
    ;;
  "Darwin")
    TARGET="node-"$NODE"-darwin-x64"
    ;;
   *)
    echo "System not supported"
    exit 3
    ;;
esac

clean_previous_installations

echo "Downloading"

export TMP_DIR=$( mktemp -d )
cd "$TMP_DIR"
if `which wget > /dev/null` ; then
  wget -q https://nodejs.org/dist/"$NODE"/"$TARGET".tar.gz
elif `which curl > /dev/null` ; then
  curl -sS -o "$TARGET".tar.gz https://nodejs.org/dist/"$NODE"/"$TARGET".tar.gz
else
  echo "wget or curl command not found"
  exit 4
fi || {
  echo "node version not found"
  echo "please provide existing version"
  rm -rf "$TMP_DIR"
  exit 5
}

tar -tzf "$TARGET".tar.gz >/dev/null
if [[ "$?" -eq 0 ]] ; then
  echo "Installing"
else
  echo "tar corrupted or not downloaded properly"
  exit 6
fi
tar xzf "$TARGET".tar.gz
rm -rf "$TARGET".tar.gz
cp -r "$TARGET"/bin/node /usr/local/bin/
mkdir -p /usr/local/lib
cp -r "$TARGET"/lib/node_modules /usr/local/lib/
cd /usr/local/bin
ln -s ../lib/node_modules/npm/bin/npm-cli.js npm
chmod +x node npm
rm -rf "$TMP_DIR"
echo "Node version "$NODE" successfully installed"

while :; do
    case $2 in
        -y|--yarn)
        echo "Installing yarn via npm"
        npm install -g yarn
        ;;
        *) break
    esac
    shift
done
