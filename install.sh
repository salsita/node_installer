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

set -euo pipefail

readonly TMP_DIR=$( mktemp -d )

function clean_on_exit() {
  rm -rf $TMP_DIR
}

function print_help() {
cat <<'eof'
Usage as root or with sudo:
  node_installer 8.9.1 # this installs 8.9.1 version
  node_installer v8.9.1 # this installs 8.9.1 version
  node_installer v8.9.1 --verbose # enables set -x
  node_installer v8.9.1 --yarn --npx # no-op options. Present for compatibility. Yarn and npx are always installed.
  node_installer v8.9.1 --cache /path # stores fetched install files to cache location. Using those and not fetching if present.
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help
eof
}

function clean_previous_installations() {
  echo "Cleaning previous node installations"
  rm -f /usr/local/bin/node
  rm -f /usr/local/bin/npm
  rm -f /usr/local/bin/yarn /usr/local/bin/yarnpkg
  rm -f /usr/local/bin/npx
  rm -rf /usr/local/lib/node_modules
}

function download() {
  local node=$1
  local target=$2
  echo "Downloading"

  if `which wget > /dev/null` ; then
    wget -q https://nodejs.org/dist/"$node"/"$target".tar.gz
  elif `which curl > /dev/null` ; then
    curl -sS -o "$target".tar.gz https://nodejs.org/dist/"$node"/"$target".tar.gz
  else
    echo "wget or curl command not found"
    exit 4
  fi || {
    echo "node version not found"
    echo "please provide existing version"
    exit 5
  }
}

function looks_like_version() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

function handle_positional_argument() {
  if [[ -z "${NODE:-}" ]] ; then
    if looks_like_version "$1" ; then
      NODE="$1"
    else
      echo "Does not look like version number: $1"
      exit 1
    fi
  else
    if looks_like_version "$1" ; then
      echo "Provide only one node version: $NODE $1"
      exit 1
    else
      echo "Unrecognized: $1"
      exit 1
    fi
  fi
}

function main() {
  [[ "$*" != *"--verbose"* ]] || set -x
  trap clean_on_exit 0

  if [[ "$1" == 'help' ]] || [[ -z "$1" ]] ; then
    print_help
    exit 0
  fi

  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root"
     print_help
     exit 1
  fi

  if [[ "$1" == clean ]] ; then
    clean_previous_installations
    exit 0
  fi

  # Defaults for options
  local NODE INSTALL_FILES_CACHE

  while [[ "$#" -ne 0 ]] ; do
    case "$1" in
      -c | --cache)
        INSTALL_FILES_CACHE="$2"
        [[ -n "${INSTALL_FILES_CACHE}" ]] || {
          echo "Cache path is empty"
          exit 1
        }
        echo "Setting cache folder: $INSTALL_FILES_CACHE"
        shift 2
        ;;

      -y | --yarn)
        echo "Yarn is always installed. '--yarn' is deprecated."
        shift
        ;;

      -n | --npx)
        echo "Npx is always installed. '--npx' is deprecated."
        shift
        ;;

      -v | --verbose)
        echo "Verbose mode active."
        shift
        ;;

      *)
        handle_positional_argument "$1"
        shift
        ;;
    esac
  done

  if [[ -z "${NODE}" ]] ; then
    echo "Provide node version"
    exit 1
  fi

  if ! [[ $NODE =~ ^v ]] ; then
    NODE=v$NODE
  fi

  if [[ ! "$NODE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "Please provide existing node version in 'X.Y.Z' or 'vX.Y.Z' format"
    exit 2
  fi
  readonly NODE

  local TARGET=
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

  if [[ -z "${INSTALL_FILES_CACHE:-}" ]] ; then
    cd "$TMP_DIR"
    download $NODE $TARGET
  else
    mkdir -p -- "$INSTALL_FILES_CACHE"
    cd -- "$INSTALL_FILES_CACHE"
    if [[ -f "$TARGET.tar.gz" ]] ; then
      echo "Using $TARGET.tar.gz from cache"
    else
      echo "No $TARGET.tar.gz  in cache"
      rm -rf "$TARGET.tar.gz"
      download $NODE $TARGET
    fi
    cp "$TARGET.tar.gz" "$TMP_DIR"
  fi

  echo "Installing"
  cd "$TMP_DIR"
  tar xf "$TARGET".tar.gz
  rm -rf "$TARGET".tar.gz
  cp -r "$TARGET"/bin/node /usr/local/bin/
  mkdir -p /usr/local/lib
  cp -r "$TARGET"/lib/node_modules /usr/local/lib/
  cd /usr/local/bin
  ln -s ../lib/node_modules/npm/bin/npm-cli.js npm
  chmod +x node npm

  echo "Linking npx"
  rm -f npx
  ln -s ../lib/node_modules/npm/bin/npx-cli.js npx
  chmod +x npx

  echo "Installing yarn"
  npm install -g yarn >/dev/null

  echo "Node version "$NODE" successfully installed"
}

main "$@"
EOF

chmod +x "$INSTALLER_PATH"
echo "node_installer successfully installed"
