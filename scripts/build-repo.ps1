# Because this repo provides the MSBuild engine, we can't really use MSBuild to build it... unless we work out some bootstrapping ;)
#
$Artifacts = Join-Path "$PSScriptRoot" artifacts
if(!(Test-Path $Artifacts)) {
    mkdir $Artifacts | Out-Null
}
$Log = Join-Path $Artifacts "buildtools.log"

function exec($cmd) {
    Write-Host -ForegroundColor DarkGray "> $cmd $args"
    & "$cmd" @args 2>&1 >$Log
}

$Projects = @(
    "aspnet-build"
)

$RepoRoot = Split-Path -Parent $PSScriptRoot

$Configuration = $env:ASPNETBUILD_CONFIGURATION
if(!$Configuration) {
    $Configuration = "Debug"
}

function EnsureDotNet() {
    $dotnetVersionFile = "$PSScriptRoot\dotnet-version.txt"
    $dotnetChannel = "rel-1.0.0"
    $dotnetVersion = Get-Content $dotnetVersionFile

    if ($env:ASPNETBUILD_DOTNET_CHANNEL)
    {
        $dotnetChannel = $env:ASPNETBUILD_DOTNET_CHANNEL
    }
    if ($env:ASPNETBUILD_DOTNET_VERSION)
    {
        $dotnetVersion = $env:ASPNETBUILD_DOTNET_VERSION
    }

    $dotnetLocalInstallFolder = "$env:LOCALAPPDATA\Microsoft\dotnet\"
    $newPath = "$dotnetLocalInstallFolder;$env:PATH"
    if ($env:ASPNETBUILD_SKIP_RUNTIME_INSTALL -eq "1")
    {
        Write-Host -ForegroundColor Green "Skipping runtime installation because ASPNETBUILD_SKIP_RUNTIME_INSTALL = 1"
        # Add to the _end_ of the path in case preferred .NET CLI is not in the default location.
        $newPath = "$env:PATH;$dotnetLocalInstallFolder"
    }
    else
    {
        Write-Host -ForegroundColor Green "Installing .NET Command-Line Tools ..."
        exec "$PSScriptRoot\dotnet-install.ps1" -Channel $dotnetChannel -Version $dotnetVersion -Architecture x64
    }
    if (!($env:Path.Split(';') -icontains $dotnetLocalInstallFolder))
    {
        Write-Host -ForegroundColor Green "Adding $dotnetLocalInstallFolder to PATH"
        $env:Path = "$newPath"
    }

    # workaround for CLI issue: https://github.com/dotnet/cli/issues/2143
    $sharedPath = (Join-Path (Split-Path ((get-command dotnet.exe).Path) -Parent) "shared");
    (Get-ChildItem $sharedPath -Recurse *dotnet.exe) | %{ $_.FullName } | Remove-Item;
}

EnsureDotNet

pushd $RepoRoot
try {
    exec dotnet restore
    $Projects | ForEach-Object {
        exec dotnet publish "$RepoRoot\src\$_" --configuration $Configuration
    }
} finally {
    popd
}
