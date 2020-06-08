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
set -eo pipefail

mkdir -p /usr/local/lib/nodejs # For installation of multiple node versions inside

#Define functions
print_help() {
echo 'Usage as root or with sudo:
  node_installer 8.9.1 or node_installer v8.9.1 # this installs 8.9.1 version
  node_installer 8.9.1 --yarn or node_installer --yarn 8.9.1 # this installs 8.9.1 version with yarn globally "npm install -g yarn"
  node_installer clean # this cleans your system from older installations done via this script
  node_installer clean-broken # removes broken symlinks
  node_installer rm-node 8.9.1 # removes the specified node version
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
remove_node_version() {
  CURRENT_NODE=`node --version`
  NODE_DIR=`ls -lrt /usr/local/lib/nodejs | grep $VERSION | awk '{print $9}'`
  if [[ "$CURRENT_NODE" == v"$VERSION" ]] ; then
    echo "Requested to remove current node version"
    rm -rf /usr/local/lib/nodejs/node-v$VERSION-*
    rm -rf /usr/local/bin/node
    rm -rf /usr/local/bin/npm
    rm -rf /usr/local/lib/node_modules
  elif [[ -z "$NODE_DIR" ]] ; then
    echo "Specified node version does not exist"
  else
    echo "Removing node version $VERSION"
    rm -rf /usr/local/lib/nodejs/node-v$VERSION-*
fi
}

#Check if script is run by root user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   print_help
   exit 1
fi

#Check positional arguments
if [[ $# -eq 0 ]] ; then
  echo "No parameters specified"
  print_help
fi
if [[ $# -gt 2 ]] ; then
  echo "Script supports maximum two arguments"
  print_help
  exit 0
fi
while [ ! -z $1 ] ; do
  case $1 in
    --yarn)
      YARN=yarn
      ;;
    [0-9]*.*[0-9]*.*[0-9]*)
      NODE=v"$1"
      echo "node version in 'x.y.z' format"
      echo $NODE
      ;;
    v[0-9]*.*[0-9]*.*[0-9]*)
      NODE="$1"
      echo  "node version in v'x.y.z' format"
      echo $NODE
      ;;
    clean)
      clean_previous_installations
      exit 0
      ;;
    clean-broken)
      remove_broken_symlinks
      exit 0
      ;;
    rm-node)
      VERSION=$2
      remove_node_version
      exit 0
      ;;
     help)
       print_help
       exit 0
      ;;
    *)
      echo wrong
      exit 1
  esac
  shift
done

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
if [[ ! -z "$PREVIOUS_NODE" ]] && [[ -f /usr/local/bin/node ]] ; then
  echo "Older node version exists, relinking to newer version after extraction"
  rm /usr/local/bin/node
  rm /usr/local/bin/npm
else
  echo "Previous versions do not exist"
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
