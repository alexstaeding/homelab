#!/bin/bash

get_latest_version() {
  wget -qO- https://api.github.com/repos/ceph/ceph/git/refs/tags | \
  jq -r '.[].ref' | \
  awk -F'/' '{print $NF}' | \
  grep '^v' | \
  sort -V | \
  tail -n1
}


# Function to check if a ref exists
ref_exists() {
  wget -qO- https://api.github.com/repos/ceph/ceph/git/refs/heads/$1 &> /dev/null || \
  wget -qO- https://api.github.com/repos/ceph/ceph/git/refs/tags/$1 &> /dev/null
}

# Read the currently installed Ceph version
if grep -q "image: quay.io/ceph/ceph:" cluster.yaml; then
  CURRENT_VERSION=$(grep "image: quay.io/ceph/ceph:" cluster.yaml | awk -F: '{print $NF}' | sed 's/ //')
  echo "Current Ceph version from cluster.yaml: ${CURRENT_VERSION}"
else
  echo "No Ceph version found in cluster.yaml. Unable to determine current version."
fi

# Initialize variables
FORCE=0

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=1
      ;;
    *)
      VERSION="$1"
      ;;
  esac
  shift
done

# Fetch and validate the new version
if [[ "$VERSION" == "stable" ]]; then
  VERSION=$(get_latest_version)
  if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
    if [[ "$FORCE" -eq 0 ]]; then
      echo "The latest stable version is ${VERSION}, which is already installed. Use --force to override. Aborting."
      exit 1
    else
      printf "\033[31mForcing upgrade to the same version ${VERSION}.\033[0m\n"
    fi
  fi
  read -p "The latest stable version is ${VERSION}. Would you like to proceed? (y/n): " proceed
  if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
    echo "Aborting."
    exit 1
  fi
elif [[ -n "$VERSION" ]]; then
  if ! ref_exists $VERSION; then
    echo "Error: The ref ${VERSION} does not exist."
    exit 1
  fi
else
  echo "No version specified. Aborting."
  exit 1
fi

# Update the cluster.yaml file
sed -i '' -e "s|image: quay.io/ceph/ceph:.*|image: quay.io/ceph/ceph:${VERSION}|" cluster.yaml

# Update suggestion
echo "cluster.yaml has been updated to version ${VERSION}."
read -p "Would you like to create a Git commit for these changes? (y/n): " choice

case "$choice" in
  y|Y ) git add cluster.yaml
        git commit -m "Upgrade Ceph to version ${VERSION}"
        ;;
  n|N ) printf "\e[33mSkipping Git commit. You can manually commit the changes later.\e[0m"
        ;;
  * )   echo "Invalid option. Skipping Git commit."
        ;;
esac
