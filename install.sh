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
cat <<'eof'
Usage as root or with sudo:
  node_installer v8.9.1 --yarn --npx # this installs 8.9.1 version, with yarn and links npx
  node_installer 8.9.1 # this installs 8.9.1 version
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help
eof
}

clean_previous_installations() {
  echo "Cleaning previous node installations"
  rm -f /usr/local/bin/node
  rm -f /usr/local/bin/npm
  rm -f /usr/local/bin/npx
  rm -f /usr/local/bin/yarn
  rm -f /usr/local/bin/yarnpkg
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

if [[ ! "$1" =~ ^[v]?[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "Please provide existing node version in 'X.Y.Z' or 'vX.Y.Z' format"
  exit 2
fi

NODE="$1"
if ! [[ $NODE =~ ^v ]] ; then
  NODE=v$NODE
fi
YARN=false
NPX=false

shift
while [[ $# != 0 ]] ; do
  if [[ $1 == '--yarn' ]] ; then
    YARN=true
  elif [[ $1 == '--npx' ]] ; then
    NPX=true
  else
    echo "Unknown parameter provided: $1"
    print_help
    exit 3
  fi
  shift
done

TARGET=
case $(uname) in
  "Linux")
    TARGET="node-${NODE}-linux-x64"
    ;;
  "Darwin")
    TARGET="node-${NODE}-darwin-x64"
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
  wget -q https://nodejs.org/dist/"$NODE"/"$TARGET".tar.xz
elif `which curl > /dev/null` ; then
  curl -sS -o "$TARGET".tar.xz https://nodejs.org/dist/"$NODE"/"$TARGET".tar.xz
else
  echo "wget or curl command not found"
  exit 4
fi || {
  echo "node version not found"
  echo "please provide existing version"
  rm -rf "$TMP_DIR"
  exit 5
}

echo "Installing"
tar xf "$TARGET".tar.xz
rm -rf "$TARGET".tar.xz
cp -r "$TARGET"/bin/node /usr/local/bin/
mkdir -p /usr/local/lib
cp -r "$TARGET"/lib/node_modules /usr/local/lib/
cd /usr/local/bin
ln -s ../lib/node_modules/npm/bin/npm-cli.js npm
chmod +x node npm
if [[ $NPX == true ]] ; then
  echo "Linking nxp"
  rm -f npx
  ln -s ../lib/node_modules/npm/bin/npx-cli.js npx
  chmod +x npx
fi
if [[ $YARN == true ]] ; then
  echo "Installing yarn"
  npm install -g yarn >/dev/null
fi
rm -rf "$TMP_DIR"
echo "Node version "$NODE" successfully installed"
EOF

chmod +x "$INSTALLER_PATH"
echo "node_installer successfully installed"
