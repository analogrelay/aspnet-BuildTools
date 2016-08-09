#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

DEFAULT_BUILD_TOOLS_BRANCH="dev"
DEFAULT_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/anurse/aspnet-BuildTools/dev/scripts/install/install-aspnet-build.sh"

[ -z "$ASPNETBUILD_TOOLS_BRANCH" ] && ASPNETBUILD_TOOLS_BRANCH="$DEFAULT_BUILD_TOOLS_BRANCH"
[ -z "$ASPNETBUILD_TOOLS_INSTALL_SCRIPT_URL" ] && ASPNETBUILD_TOOLS_INSTALL_SCRIPT_URL="$DEFAULT_INSTALL_SCRIPT_URL"

INSTALL_SCRIPT="$DIR/.build/install-aspnet-build.sh"

if [ ! -e "$INSTALL_SCRIPT" ]; then
    INSTALL_DIR=$(dirname "$INSTALL_SCRIPT")
    if [ ! -e "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi

    echo "$(tput setaf 2)Fetching install script from $ASPNETBUILD_TOOLS_INSTALL_SCRIPT_URL ...$(tput setaf 7)"
    curl -sSL -o "$INSTALL_SCRIPT" "$ASPNETBUILD_TOOLS_INSTALL_SCRIPT_URL"
fi

TRAINFILE="$DIR/Trainfile"
REPOFILE="$DIR/Repofile"
if [ -e "$TRAINFILE" ]; then
    "$INSTALL_SCRIPT" --trainfile "$TRAINFILE"
elif [ -e "$REPOFILE" ]; then
    "$INSTALL_SCRIPT" --trainfile "$REPOFILE"
else
    "$INSTALL_SCRIPT" --branch "$ASPNETBUILD_TOOLS_BRANCH"
fi

BUILD_TOOLS_PATH=$("$INSTALL_SCRIPT" --get-path --branch "$ASPNETBUILD_TOOLS_BRANCH")

"$BUILD_TOOLS_PATH/bin/aspnet-build" "$@"