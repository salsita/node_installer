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
  node_installer v8.9.1 --cache /path # stores fetched install files to cache location. Using those and not fetching if present.
  node_installer 8.9.1 # this installs 8.9.1 version
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help
eof
}

clean_previous_installations() {
  echo "Cleaning previous node installations"
  rm -f /usr/local/bin/node
  rm -f /usr/local/bin/npm
  $1 # RM_YARN
  $2 # RM_NPX
  rm -rf /usr/local/lib/node_modules
}

download() {
  echo "Downloading"

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
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   print_help
   exit 1
fi

if [[ "$1" == 'help' ]] || [[ -z "$1" ]] ; then
  print_help
  exit 0
fi

YARN=false
RM_YARN=":"
NPX=false
RM_NPX=":"
INSTALL_FILES_CACHE=

set +e
PARSED_ARGUMENTS=$(getopt -n node_installer -o ync: --long yarn,npx,cache: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  print_help
  exit 1
fi
set -e

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -y | --yarn)  YARN=true ; RM_YARN="rm -f /usr/local/bin/yarn /usr/local/bin/yarnpkg" ; shift ;;
    -n | --npx)   NPX=true  ; RM_NPX="rm -f /usr/local/bin/npx" ; shift ;;
    -c | --cache) INSTALL_FILES_CACHE="$2" ; shift 2 ;;
    --)           shift; break ;;
    *) echo "Unexpected option: $1 - this should not happen." ; print_help ; exit 1 ;;
  esac
done

NODE=
if [[ "$#" -eq 0 ]] ; then
  echo "Pass node version"
  exit 1
elif [[ "$#" -ne 1 ]] ; then
  echo "Expected single positional argument (node version). Passed more: $@"
  exit 1
else
  NODE="$1"
fi

if ! [[ $NODE =~ ^v ]] ; then
  NODE=v$NODE
fi

if [[ "$NODE" == 'vclean' ]] ; then
  clean_previous_installations "$RM_YARN" "$RM_NPX"
  exit 0
fi

if [[ ! "$NODE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
  echo "Please provide existing node version in 'X.Y.Z' or 'vX.Y.Z' format"
  exit 2
fi

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

clean_previous_installations "$RM_YARN" "$RM_NPX"

export TMP_DIR=$( mktemp -d )

if [[ -z "$INSTALL_FILES_CACHE" ]] ; then
  download
else
  mkdir -p "$INSTALL_FILES_CACHE"
  cd "$INSTALL_FILES_CACHE"
  if [[ -f "$TARGET.tar.gz" ]] ; then
    echo "Using $TARGET.tar.gz from cache"
  else
    echo "No $TARGET.tar.gz  in cache"
    rm -rf "$TARGET.tar.gz"
    download
  fi
  cp "$TARGET.tar.gz" "$TMP_DIR"
fi

echo "Installing"
tar xf "$TARGET".tar.gz
rm -rf "$TARGET".tar.gz
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
