#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
BUILD_TOOLS_ROOT="$( cd -P "$DIR/.." && pwd)"

if [ -e "$BUILD_TOOLS_ROOT/.initialized" ]; then
    echo "ASP.NET Build Tools are already initialized!"
else
    echo "Initializing ASP.NET Build Tools..."
    DOTNET_INSTALL_DIR="$BUILD_TOOLS_ROOT/dotnet-cli"
    if [ ! -d $DOTNET_INSTALL_DIR ]; then
        mkdir $DOTNET_INSTALL_DIR
    fi

    VERSION_FILE="$BUILD_TOOLS_ROOT/dotnet-install/dotnet-version.txt"
    DEFAULT_VERSION=$(cat $VERSION_FILE)

    [ ! -z "$ASPNETBUILD_DOTNET_CHANNEL" ] || ASPNETBUILD_DOTNET_CHANNEL="rel-1.0.0"
    [ ! -z "$ASPNETBUILD_DOTNET_VERSION" ] || ASPNETBUILD_DOTNET_VERSION=$DEFAULT_VERSION

    if [ "$ASPNETBUILD_SKIP_RUNTIME_INSTALL" = "1" ]; then
        echo "Skipping runtime installation because ASPNETBUILD_SKIP_RUNTIME_INSTALL is set to '1'"
    else
        echo "Installing .NET Command-Line Tools ..."
        "$BUILD_TOOLS_ROOT/dotnet-install/dotnet-install.sh" --no-path --install-dir "$DOTNET_INSTALL_DIR" --channel $ASPNETBUILD_DOTNET_CHANNEL --version $ASPNETBUILD_DOTNET_VERSION --arch x64
    fi

    FOUND=`find $DOTNET_INSTALL_DIR/shared -name dotnet`
    if [ ! -z "$FOUND" ]; then
        echo $FOUND | xargs rm
    fi

    date --utc +"%Y-%m-%dT%H:%M:%S.%NZ" > "$BUILD_TOOLS_ROOT/.initialized"
fi