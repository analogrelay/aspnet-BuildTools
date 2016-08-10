#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
PARENT="$( cd -P "$DIR/.." && pwd)"

DOTNET="$PARENT/dotnet-cli/dotnet"
DEFAULT_MAKEFILE="$PARENT/Microsoft.AspNetCore.Build/msbuild/DefaultMakefile.proj"

if [ ! -e "$DOTNET" ]; then
    echo "error: Tools have not been initialized yet. Run the init-aspnet-build.sh script in the build tools." 1>&2
    exit 1
fi 

_get_makefile_for() {
  local dir=$1
  local candidate="$dir/makefile.proj"

  cd $dir

  if [ -e $candidate ]; then
    echo $candidate
  else
    echo $DEFAULT_MAKEFILE
  fi
}

# Scan the args to identify if we're building a project or repo
SAW_PROJECT=
NEW_ARGS=()
while [ $# -gt 0 ]; do
  case $1 in
    -*|/*)
      NEW_ARGS+=($1)
      ;;
    *)
      SAW_PROJECT=1
      if [ -d $1 ]; then
        MKFILE=$(_get_makefile_for $1)
        NEW_ARGS+=($MKFILE)
      else
        NEW_ARGS+=($1)
      fi
  esac
done

if [ -z $SAW_PROJECT ]; then
  NEW_ARGS=( ${NEW_ARGS[@]} $(_get_makefile_for .))
fi

NEW_ARGS+=("/p:AspNetBuildRoot=$PARENT")

# Workaround for https://github.com/Microsoft/msbuild/issues/754
NEW_ARGS+=("/clp:DisableConsoleColor")

echo "> dotnet build3 ${NEW_ARGS[@]}"
PATH="$(dirname $DOTNET):$PATH" "$DOTNET" build3 "${NEW_ARGS[@]}"