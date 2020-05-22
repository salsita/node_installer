#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

INSTALLER_PATH="/usr/local/bin/node_installer"

mkdir -p /usr/local/bin

cat > "$INSTALLER_PATH" << 'EOF'
#!/bin/bash
set -e

mkdir -p /usr/local/lib/nodejs # For installation of multiple node versions inside

#Define functions
print_help() {
echo 'Usage as root or with sudo:
  node_installer 8.9.1 or node_installer v8.9.1 # this installs 8.9.1 version
  node_installer 8.9.1 --yarn or node_installer --yarn 8.9.1 # this installs 8.9.1 version with yarn globally "npm install -g yarn"
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help'
}
clean_previous_installations() {
  echo "Cleaning previous node installations"
  rm -rf /usr/local/bin/node
  rm -rf /usr/local/bin/npm
  rm -rf /usr/local/lib/node_modules
  rm -rf /usr/local/lib/nodejs/node-*
}

remove_broken_symlinks() {
  find -L /usr/local/bin -maxdepth 1 -type l
  find -L /usr/local/bin -maxdepth 1 -type l -exec rm -- {} +
}

#Check positional arguments
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   print_help
   exit 1
fi

if [[ $# -gt 2 ]] ; then
  echo "Script supports maximum two arguments"
  print_help
  exit 0
fi

if [[ "$1" == 'clean' ]] ; then
  clean_previous_installations
  exit 0
fi

if [[ "$1" == 'help' ]] || [[ -z "$1" ]] ; then
  print_help
  exit 0
fi

if [[ "$1" == "--yarn" ]] ; then
  shift
  YARN=yarn
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

#Download node binaries
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

#Check for previous versions and prepare for new installation
PREVIOUS_NODE=`ls -l /usr/local/lib/nodejs/ | awk '{print $9}'`
if [[ ! -z "$PREVIOUS_NODE" ]] ; then
  echo "Older node version exists, relinking to newer version after extraction"
  rm /usr/local/bin/node
  rm /usr/local/bin/npm
fi

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
tar -tzf "$TARGET".tar.gz >/dev/null  # Test the tar file downloaded properly or not
if [[ "$?" -eq 0 ]] ; then
  echo "Installing"
else
  echo "tar corrupted or not downloaded properly"
  exit 6
fi

#Node installation
tar -xJf "$TMP_DIR"/"$TARGET".tar.gz -C /usr/local/lib/nodejs
ln -s /usr/local/lib/nodejs/$TARGET/bin/node /usr/local/bin/node
ln -s /usr/local/lib/nodejs/$TARGET/bin/npm /usr/local/bin/npm
npm config set prefix /usr/local

#Yarn installation
while :; do
    case $2 in
        --yarn)
        echo "Installing yarn via npm"
        npm install -g yarn
        ;;
        *) break
    esac
    shift
done
if [[ ! -z "$YARN" ]] ; then
  echo "Installing yarn via npm"
  npm install -g $YARN
fi

#Remove broken symlinks
remove_broken_symlinks
EOF

chmod +x "$INSTALLER_PATH"
echo "node_installer successfully installed"
