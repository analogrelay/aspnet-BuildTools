$BuildCommit = git rev-parse HEAD
$BuildBranch = git rev-parse --abbrev-ref HEAD

Write-Host -ForegroundColor Green "Producing Build Tools in $BuildBranch at Commit $BuildCommit"

# Because this repo provides the MSBuild engine, we can't really use MSBuild to build it... unless we work out some bootstrapping ;)
$RepoRoot = Split-Path -Parent $PSScriptRoot

if(!(Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "Expected 'dotnet' to already be on the PATH!"
}

$Projects = @(
    "aspnet-build"
)

$RepoRoot = Split-Path -Parent $PSScriptRoot

$Configuration = $env:ASPNETBUILD_CONFIGURATION
if(!$Configuration) {
    $Configuration = "Debug"
}

# Build projects
pushd $RepoRoot
try {
    & dotnet restore
    $Projects | ForEach-Object {
        & dotnet publish "$RepoRoot\src\$_" --configuration $Configuration
    }
} finally {
    popd
}

Write-Host -ForegroundColor Green "Preparing layout..."

# Assemble the output
$Artifacts = Join-Path $RepoRoot artifacts
if(!(Test-Path $Artifacts)) {
    mkdir $Artifacts | Out-Null
}

$OutputDir = Join-Path $Artifacts "layout"
if(Test-Path $OutputDir) {
    del -rec -for $OutputDir
}
mkdir $OutputDir | Out-Null

# Launcher
mkdir "$OutputDir\bin" | Out-Null
cp "$PSScriptRoot\bin\aspnet-build.template.cmd" "$OutputDir\bin\aspnet-build.cmd"
cp "$PSScriptRoot\bin\aspnet-build.template.sh" "$OutputDir\bin\aspnet-build"

# DotNet CLI install scripts
mkdir "$OutputDir\dotnet-install" | Out-Null
cp "$PSScriptRoot\dotnet-install\*" "$OutputDir\dotnet-install"

# aspnet-build
mkdir "$OutputDir\aspnet-build" | Out-Null
cp -rec "$RepoRoot\src\aspnet-build\bin\$Configuration\netcoreapp1.0\publish\*" "$OutputDir\aspnet-build"

# init scripts
mkdir "$OutputDir\init" | Out-Null
cp "$PSScriptRoot\init\*" "$OutputDir\init"

# Version file
[DateTime]::UtcNow.ToString("O") > "$OutputDir\.builddateutc"
"$BuildCommit" > "$OutputDir\.commit"

Write-Host -ForegroundColor Green "Packaging tools ..."

try {
    Add-Type -Assembly "System.IO.Compression.FileSystem"
} catch {
    throw "Failed to load System.IO.Compression.FileSystem.dll, which is required."
    exit
}
$OutputName = "aspnet-build.$BuildBranch.zip"
$OutputFile = Join-Path $Artifacts $OutputName
if(Test-Path $OutputFile) {
    del $OutputFile
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutputDir, $OutputFile)
Write-Host "Packaged tools to $OutputFile"

Write-Host -ForegroundColor Green "Initializing compiled tools in-place for use in testing ..."

& "$OutputDir\init\init-aspnet-build.ps1"