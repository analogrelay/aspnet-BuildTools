#!/usr/bin/env bash
set -e

Bk=$(tput setaf 0)
Rd=$(tput setaf 1)
Gr=$(tput setaf 2)
Ye=$(tput setaf 3)
Bl=$(tput setaf 4)
Ma=$(tput setaf 5)
Cy=$(tput setaf 6)
Wh=$(tput setaf 7)
Rs=$Wh

DEFAULT_SOURCE_FEED="https://anurseaspnetbuildtools.blob.core.windows.net/aspnetbuildpackages"

ARG0=$0

die() {
    usage
    echo -e "${Rd}error:${Rs} $1" 1>&2
    exit 1
}

assert() {
    if [ -z $1 ]; then
        die $2
    fi
}

usage() {
    echo "USAGE: "
    echo "  ${Cy}$ARG0${Rs} [${Ye}--install${Rs}] [${Ye}--source-feed${Rs} ${Ma}<PACKAGE_FEED>${Rs}] [${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}] [${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}]"
    echo "  ${Cy}$ARG0${Rs} [${Ye}--install${Rs}] ${Ye}--source-package${Rs} ${Ma}<PACKAGE_PATH>${Rs} [${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}] [${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}]"
    echo "  ${Cy}$ARG0${Rs} [${Ye}--install${Rs}] ${Ye}--source-url${Rs} ${Ma}<PACKAGE_URL>${Rs} [${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}] [${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}]"
    echo "  ${Cy}$ARG0${Rs} ${Ye}--list${Rs} [${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}] [${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}]"
    echo "  ${Cy}$ARG0${Rs} ${Ye}--get-path${Rs} [${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}] [${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}]"
    echo ""
    echo "COMMANDS"
    echo "  ${Ye}--install${Rs}       install the ASP.NET Build Tools (this is the default command)"
    echo "  ${Ye}--list${Rs}          list installed branches of the ASP.NET Build Tools"
    echo "  ${Ye}--get-path${Rs}      gets the path to the root of the active ASP.NET Build Tools install"
    echo ""
    echo "SOURCE OPTIONS (for ${Ye}--install${Rs} only)"
    echo "  ${Ye}--source-feed${Rs} ${Ma}<PACKAGE_FEED>${Rs}        the base URL of the feed to install packages from"
    echo "  ${Ye}--source-url${Rs} ${Ma}<PACKAGE_URL>${Rs}          the URL of the package to install"
    echo "  ${Ye}--source-package${Rs} ${Ma}<PACKAGE_PATH>${Rs}     the local path to the pacakge to install"
    echo "  ${Rd}NOTE${Rs}: only one of the ${Ye}--source-*${Rs} options can be provided."
    echo ""
    echo "OPTIONS"
    echo "  ${Ye}--branch${Rs} ${Ma}<BRANCH>${Rs}                   the branch of the ASP.NET Build Tools to use as the active branch (for ${Ye}--install${Rs} and ${Ye}--get-path${Rs})"
    echo "  ${Ye}--install-dir${Rs} ${Ma}<INSTALLDIR>${Rs}          the root installation directory for ASP.NET Build Tools (default: ~/.aspnet-build)"
}

while [ $# -gt 0 ]; do
    case $1 in
        -h|-\?|--help)
            usage
            exit
            ;;
        --source-url|-u)
            [ -z $SOURCE_PACKAGE ] || die "can't specify both --source-package and --source-url"
            [ -z $SOURCE_FEED ] || die "can't specify both --source-feed and --source-url"
            SOURCE_URL=$2
            shift
            ;;
        --source-package|-p)
            [ -z $SOURCE_FEED ] || die "can't specify both --source-feed and --source-package"
            [ -z $SOURCE_URL ] || die "can't specify both --source-url and --source-package"
            SOURCE_PACKAGE=$2
            shift
            ;;
        --source-feed|-f)
            [ -z $SOURCE_PACKAGE ] || die "can't specify both --source-package and --source-feed"
            [ -z $SOURCE_URL ] || die "can't specify both --source-url and --source-feed"
            SOURCE_FEED=$2
            shift
            ;;
        --branch|-b)
            BRANCH=$2
            shift
            ;;
        --install-dir|-d)
            INSTALLDIR=$2
            shift
            ;;
        --install|-i)
            [ -z $CMD ] || die "specified multiple commands: --$CMD and --install"
            CMD="install"
            ;;
        --list|-l)
            [ -z $CMD ] || die "specified multiple commands: --$CMD and --list"
            CMD="list"
            ;;
        --get-path)
            [ -z $CMD ] || die "specified multiple commands: --$CMD and --get-path"
            CMD="get-path"
            ;;
        *)
            die "unrecognized argument: $1"
            ;;
    esac
    shift
done

# Prereq check
if ! type -p unzip >/dev/null 2>/dev/null; then
    die "missing prerequisite: unzip"
fi

[ -z $CMD ] && CMD="install"
[ -z $INSTALLDIR ] && INSTALLDIR="$HOME/.aspnet-build"
[ -z $BRANCH ] && BRANCH="dev"

cmd_list() {
    die "not yet implemented"
}

cmd_get_path() {
    die "not yet implemented"
}

_get_branch() {
    echo $1 | sed "s/aspnet-build\.\([^\.]\+\)\.zip/\1/g" 
}

_get_install_path() {
    echo "$INSTALLDIR/branches/$1"
}

_install_package() {
    assert "$SOURCE_PACKAGE" "install_package expects \$SOURCE_PACKAGE to be set!"
    
    local etag=$1
    local package_file_name=$(basename $SOURCE_PACKAGE)
    local package_branch=$(_get_branch $package_file_name)
    local install_path=$(_get_install_path $package_branch)

    # Clean and recreate the existing dir
    [ -d $install_path ] && rm -Rf $install_path
    mkdir -p $install_path

    # Extract
    # Since the ZIP has "\" as a path separator, we need to set +e to allow failure
    # We also count the number of extract files and compare to the expected results to ensure we don't miss any files because of errors we're ignoring
    local linecount=$(unzip -l $SOURCE_PACKAGE | wc -l)
    local expected_files=$(($linecount - 5)) # There are 5 extra lines in the output
    
    set +e
    local zipoutput=$(unzip $SOURCE_PACKAGE -d $install_path 2>&1)
    set -e

    local unzipped_files=$(echo "$zipoutput" | grep -c inflating)
    if [ $expected_files != $unzipped_files ]; then
        echo "$expected_files != $unzipped_files"
        rm -Rf $install_path
        die "failed to unpack; unzip output:\n$zipoutput"
    fi

    if [ ! -z $etag ]; then
        echo "$etag" > "$install_path/.etag"
    fi

    # Initialize the installed package
    chmod a+x "$install_path/init/init-aspnet-build.sh"
    "$install_path/init/init-aspnet-build.sh"
}

_install_url() {
    assert "$SOURCE_URL" "install_url expects \$SOURCE_URL to be set!"
    if [[ $SOURCE_URL != http* ]]; then
        die "Source URL must be an HTTP(S) endpoint!"
    fi

    local package_file_name=$(basename $SOURCE_URL)
    local package_branch=$(_get_branch $package_file_name)
    local install_path=$(_get_install_path $package_branch)

    if [ -e "$install_path/.etag" ]; then
        echo "${Gr}Tools for $package_branch are already installed. Checking for updates...${Rs}"
        local etag=$(cat "$install_path/.etag" | tr -d '\r\n')

        # Check for a new version
        if curl -sSL -I -H "If-None-Match: $etag" $SOURCE_URL | grep "HTTP/1\.1 304" >/dev/null 2>/dev/null; then
            echo "The latest version of the ASP.NET Build Tools from branch $package_branch are already present in $install_path"
            exit 0
        fi
        echo "Your build tools are out-of-date. Downloading the latest build tools."
    fi

    # If we're here, we need to fetch a new package
    local temp=$(mktemp -d)
    local headers_file="$temp/headers.txt"
    local download_file="$temp/$package_file_name"

    echo "${Gr}Downloading ASP.NET Build Tools Package from $SOURCE_URL${Rs}"
    curl -f -o $download_file -sSL $SOURCE_URL -D $headers_file

    local etag=$(cat $headers_file | grep "ETag:" | sed "s/ETag: //g")
    rm $headers_file

    SOURCE_PACKAGE=$download_file
    _install_package $etag
    rm -Rf $temp
}

_install_feed() {
    if [[ "$SOURCE_FEED" == */ ]]; then
        SOURCE_FEED=$(echo "$SOURCE_FEED" | sed 's/\/$//g')
    fi
    SOURCE_URL="$SOURCE_FEED/aspnet-build.$BRANCH.zip"
    _install_url
}

cmd_install() {
    if [ ! -z "$SOURCE_PACKAGE" ]; then
        _install_package
    elif [ ! -z "$SOURCE_URL" ]; then
        _install_url
    elif [ ! -z "$SOURCE_FEED"]; then
        _install_feed
    else
        SOURCE_FEED=$DEFAULT_SOURCE_FEED
        _install_feed
    fi
}

if [ "$CMD" = "list" ]; then
    cmd_list
elif [ "$CMD" = "get-path" ]; then
    cmd_get_path
elif [ "$CMD" = "install" ]; then
    cmd_install
else
    die "unknown command: $CMD"
fi