@echo off
dotnet --version 2>nul >nul || (
    echo Could not find 'dotnet' launcher... 1>&2
    exit 1
)

dotnet "%~dp0aspnet-build.dll"