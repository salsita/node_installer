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

if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "Please provide existing node version in 'x.y.z' format"
  exit 2
fi

NODE="$1"
TARGET="node-v"$NODE"-linux-x64"

clean_previous_installations

which wget || {
  echo "wget command not found"
  exit 3
}

export TMP_DIR=$( mktemp -d )
cd "$TMP_DIR"
wget https://nodejs.org/dist/v"$NODE"/"$TARGET".tar.xz || {
  echo "node version not found"
  echo "please provide existing version"
  rm -rf "$TMP_DIR"
  exit 4
}
tar xf "$TARGET".tar.xz
rm -rf "$TARGET".tar.xz
cp -r "$TARGET"/bin/node /usr/local/bin/
mkdir -p /usr/local/lib
cp -r "$TARGET"/lib/node_modules /usr/local/lib/
cd /usr/local/bin
ln -s ../lib/node_modules/npm/bin/npm-cli.js npm
chmod +x node npm
rm -rf "$TMP_DIR"
EOF

chmod +x "$INSTALLER_PATH"
