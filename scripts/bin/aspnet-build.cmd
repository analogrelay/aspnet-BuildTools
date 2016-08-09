@echo off

set DOTNET="%~dp0..\dotnet-cli\dotnet.exe"
set ASPNET_BUILD="%~dp0..\aspnet-build\aspnet-build.dll"

if not exist %DOTNET% (
    echo error: Tools have not been initialized yet. Run the init-aspnet-build.ps1 script in the build tools.
    exit 1
)

"%DOTNET%" "%ASPNET_BUILD%" %*