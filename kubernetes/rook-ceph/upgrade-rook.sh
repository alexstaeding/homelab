#!/bin/bash

# Function to get the latest version tag from Rook GitHub repo
get_latest_version() {
  wget -qO- https://api.github.com/repos/rook/rook/releases/latest | \
  grep '"tag_name":' | \
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to check if a ref exists
ref_exists() {
  wget -qO- https://api.github.com/repos/rook/rook/git/refs/heads/$1 &> /dev/null || \
  wget -qO- https://api.github.com/repos/rook/rook/git/refs/tags/$1 &> /dev/null
}

# Function to check if the ref is a tag
is_tag() {
  wget -qO- https://api.github.com/repos/rook/rook/git/refs/tags/$1 &> /dev/null
}

# Read the currently installed version
if [[ -f "rook-version.txt" ]]; then
  CURRENT_VERSION=$(<rook-version.txt)
  echo "Current version from rook-version.txt: ${CURRENT_VERSION}"
else
  echo "No rook-version.txt found. Unable to determine current version."
fi

# Validate input
if [[ "$#" -eq 0 ]]; then
  echo "No argument provided. Aborting."
  echo "Usage: ./upgrade-rook.sh [stable | <version>]"
  exit 1
elif [[ "$#" -ne 1 ]]; then
  echo "Invalid number of arguments. Usage: ./upgrade-rook.sh [stable | <version>]"
  exit 1
fi

# Fetch and validate the new version
if [[ "$1" == "stable" ]]; then
  VERSION=$(get_latest_version)
  read -p "The latest stable version is ${VERSION}. Would you like to proceed? (y/n): " proceed
  if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
    echo "Aborting."
    exit 1
  fi
else
  VERSION=$1
  if ! ref_exists $VERSION; then
    echo "Error: The ref ${VERSION} does not exist."
    exit 1
  elif ! is_tag $VERSION; then
    read -p "Warning: The ref ${VERSION} is not a tag. Proceed anyway? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Aborting."
      exit 1
    fi
  fi
fi

# Update the operator.yaml file
sed -i "s|image: rook/ceph:.*|image: rook/ceph:${VERSION}|" operator.yaml

# Fetch the new YAML files
COMMON_URL="https://raw.githubusercontent.com/rook/rook/${VERSION}/deploy/examples/common.yaml"
CRDS_URL="https://raw.githubusercontent.com/rook/rook/${VERSION}/deploy/examples/crds.yaml"
wget -O common.yaml $COMMON_URL
wget -O crds.yaml $CRDS_URL

# Update rook-version.txt
echo $VERSION > rook-version.txt

# Suggest to create a Git commit
echo "Files common.yaml, crds.yaml, and operator.yaml have been updated to version ${VERSION}."
echo "rook-version.txt has been updated to version ${VERSION}."
read -p "Would you like to create a Git commit for these changes? (y/n): " choice

case "$choice" in
  y|Y ) git add common.yaml crds.yaml operator.yaml rook-version.txt
        git commit -m "Upgrade Rook-Ceph to version ${VERSION}"
        ;;
  n|N ) echo "Skipping Git commit. You can manually commit the changes later."
        ;;
  * )   echo "Invalid option. Skipping Git commit."
        ;;
esac
