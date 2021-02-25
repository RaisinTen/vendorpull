#!/bin/sh

set -o errexit
DEPENDENCY="$1"
set -o nounset

DEPENDENCIES_FILE="$PWD/DEPENDENCIES"
VENDOR_DIRECTORY="$PWD/vendor"
mkdir -p "$VENDOR_DIRECTORY"

if ! command -v git > /dev/null
then
  echo "You must install git in order to use this tool" 1>&2
  exit 1
fi

TEMPORARY_DIRECTORY="$(mktemp -d -t vendorpull)"
temporary_directory_clean() {
  rm -rf "$TEMPORARY_DIRECTORY"
}

# shellcheck disable=SC2039
trap temporary_directory_clean ERR

if [ ! -f "$DEPENDENCIES_FILE" ]
then
  echo "Could not find a dependencies manifest at:" 1>&2
  echo "  $DEPENDENCIES_FILE" 1>&2
  exit 1
fi

assert_defined() {
  if [ -z "$1" ]
  then
    echo "$2" 1>&2
    exit 1
  fi
}

mask_directory() {
  while read -r pattern
  do
    echo "Applying mask: $pattern" 1>&2
    MATCHES="$(find "$1" -name "$pattern")"
    for file in $MATCHES
    do
      rm -rf "$file"
    done
  done < "$2"
}

install_dependency() {
  NAME="$(echo "$1" | cut -d ' ' -f 1)"
  REPOSITORY="$(echo "$1" | cut -d ' ' -f 2)"
  REVISION="$(echo "$1" | cut -d ' ' -f 3)"

  assert_defined "$NAME" "ERROR: Missing dependency name"
  assert_defined "$REPOSITORY" "$NAME: ERROR: Missing repository URL"
  assert_defined "$REVISION" "$NAME: ERROR: Missing git revision"

  OUTPUT_DIRECTORY="$VENDOR_DIRECTORY/$NAME"
  GIT_REPOSITORY_DIRECTORY="$TEMPORARY_DIRECTORY/$NAME"

  git clone "$REPOSITORY" "$GIT_REPOSITORY_DIRECTORY"
  git -C "$GIT_REPOSITORY_DIRECTORY" reset --hard "$REVISION"
  rm -rf "$GIT_REPOSITORY_DIRECTORY/.git"

  MASK_FILE="$VENDOR_DIRECTORY/$NAME.mask"
  if [ -f "$MASK_FILE" ]
  then
    mask_directory "$GIT_REPOSITORY_DIRECTORY" "$MASK_FILE"
  fi

  rm -rf "$OUTPUT_DIRECTORY"
  mv "$TEMPORARY_DIRECTORY/$NAME" "$OUTPUT_DIRECTORY"
}

if [ -n "$DEPENDENCY" ]
then
  DEFINITION="$(grep "^$DEPENDENCY" < "$DEPENDENCIES_FILE" | head -n 1)"
  if [ -z "$DEFINITION" ]
  then
    echo "Could not find a dependency named: $DEPENDENCY" 1>&2
    exit 1
  fi

  install_dependency "$DEFINITION"
else
  while read -r dependency
  do
    install_dependency "$dependency"
  done < "$DEPENDENCIES_FILE"
  temporary_directory_clean
fi
