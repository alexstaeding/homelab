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

# Read the currently installed version from rook-version.txt, if available
if [[ -f "rook-version.txt" ]]; then
  CURRENT_VERSION=$(<rook-version.txt)
  echo "Current version from rook-version.txt: ${CURRENT_VERSION}"
else
  echo "No rook-version.txt file found. Unable to determine current version."
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

# Define URLs
COMMON_URL="https://raw.githubusercontent.com/rook/rook/${VERSION}/deploy/examples/common.yaml"
CRDS_URL="https://raw.githubusercontent.com/rook/rook/${VERSION}/deploy/examples/crds.yaml"

# Fetch files using wget
wget -O common.yaml $COMMON_URL
wget -O crds.yaml $CRDS_URL

# Update rook-version.txt with the new version
echo $VERSION > rook-version.txt

# Suggest to create a Git commit
echo "Files common.yaml and crds.yaml have been updated to version ${VERSION}."
echo "rook-version.txt has been updated to version ${VERSION}."
read -p "Would you like to create a Git commit for these changes? (y/n): " choice

case "$choice" in
  y|Y ) git add common.yaml crds.yaml rook-version.txt
        git commit -m "Upgrade Rook-Ceph to version ${VERSION}"
        ;;
  n|N ) echo "Skipping Git commit. You can manually commit the changes later."
        ;;
  * )   echo "Invalid option. Skipping Git commit."
        ;;
esac
