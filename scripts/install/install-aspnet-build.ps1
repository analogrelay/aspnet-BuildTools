[CmdletBinding(DefaultParameterSetName="InstallFromFeed")]
param(
    [Parameter(ParameterSetName="InstallFromUrl", Mandatory=$true)]
    [string]$SourceUrl,

    [Parameter(ParameterSetName="InstallFromPackage", Mandatory=$true)]
    [string]$SourcePackage,

    [Parameter(ParameterSetName="InstallFromFeed")]
    [string]$SourceFeed,
    
    [Parameter(ParameterSetName="InstallViaTrainfile")]
    [string]$Trainfile,

    [Parameter(ParameterSetName="InstallFromFeed")]
    [Parameter(ParameterSetName="AddToPath")]
    [Parameter(ParameterSetName="GetPath")]
    [string]$BuildToolsBranch,

    [string]$InstallationDirectory,

    [Parameter(ParameterSetName="List", Mandatory=$true)]
    [switch]$List,

    [Parameter(ParameterSetName="AddToPath", Mandatory=$true)]
    [switch]$AddToPath,

    [Parameter(ParameterSetName="CleanPath", Mandatory=$true)]
    [switch]$CleanPath,

    [Parameter(ParameterSetName="GetPath", Mandatory=$true)]
    [switch]$GetPath
)

$ErrorActionPreference = "Stop"

$PackageNamePattern = "aspnet-build\.(.*)\.zip"

if(!$SourceFeed) {
    $SourceFeed = "https://anurseaspnetbuildtools.blob.core.windows.net/aspnetbuildpackages"
}

if($SourceFeed.EndsWith("/")) {
    $SourceFeed = $SourceFeed.Substring(0, $SourceFeed.Length - 1)
}

if(!$InstallationDirectory) {
    $InstallationDirectory = Join-Path $env:LOCALAPPDATA "Microsoft"
    $InstallationDirectory = Join-Path $InstallationDirectory "aspnet-build"
}

if(!$BuildToolsBranch) {
    $BuildToolsBranch = "dev"
}

function DoList() {
    if(!(Test-Path $InstallationDirectory)) {
        "No versions of ASP.NET Build are installed in '$InstallationDirectory'"
    }

    dir "$InstallationDirectory\branches" | ForEach-Object { $_.Name }
}

function AddToPath() {
    $InstallPath = GetInstallPath $BuildToolsBranch
    $env:PATH = "$InstallPath\bin;$env:PATH"
}

function CleanPath() {
    $newPathItems = $env:PATH.Split([IO.Path]::PathSeparator) | where { !$_.StartsWith($InstallationDirectory) }
    $env:PATH = [string]::Join([IO.Path]::PathSeparator, $newPathItems)
}

function GetInstallPath($Branch) {
    Join-Path (Join-Path $InstallationDirectory "branches") $Branch
}

function GetBranch($PackageFileName)
{
    if($PackageFileName -notmatch $PackageNamePattern) {
        throw "Invalid Package File Name: $PackageFileName"
    }
    [regex]::Replace($PackageFileName, $PackageNamePattern, "`$1")
}

function InstallFromUrl {
    if(!$SourceUrl.StartsWith("http")) {
        throw "Source URL must be an HTTP(S) endpoint!"
    }

    # Identify the Branch from the URL
    $PackageFileName = Split-Path -Leaf $SourceUrl

    $PackageBranch = GetBranch $PackageFileName
    $InstallPath = GetInstallPath $PackageBranch

    if(Test-Path "$InstallPath\.etag") {
        Write-Host "Tools for $PackageBranch are already installed. Checking for updates..."
        $ETag = [IO.File]::ReadAllText((Convert-Path "$InstallPath\.etag"))

        # Check if there's actually a new version available
        try {
            $resp = Invoke-WebRequest $SourceUrl -Method Head -Headers @{"If-None-Match" = $ETag} 
        } catch {
            $resp = $_.Exception.Response
        }

        if($resp.StatusCode -eq "NotModified") {
            # It's already installed!
            Write-Host -ForegroundColor Green "The latest version of the ASP.NET Build Tools from branch $PackageBranch are already present in $InstallPath"
            return
        }
        Write-Host "Your build tools are out-of-date. Downloading the latest build tools."
    }

    # If we made it here, either a) There is no existing install or b) The ETag didn't match so there's a new version

    $TempFile = Join-Path ([IO.Path]::GetTempPath()) $PackageFileName
    if(Test-Path $TempFile) {
        del -LiteralPath -Force $TempFile
    }
    Write-Host -ForegroundColor Green "Downloading ASP.NET Build Tools Package from $SourceUrl"

    $resp = Invoke-WebRequest $SourceUrl -OutFile $TempFile -PassThru
    $ETag = $resp.Headers.ETag
    
    $SourcePackage = $TempFile
    InstallFromPackage $ETag
}

function InstallFromPackage($ETag) {
    Write-Host -ForegroundColor Green "Installing Build Tools..."

    $PackageFileName = Split-Path -Leaf $SourcePackage

    $PackageBranch = GetBranch $PackageFileName
    $InstallPath = GetInstallPath $PackageBranch

    try {
        Add-Type -Assembly "System.IO.Compression.FileSystem"
    } catch {
        throw "Failed to load System.IO.Compression.FileSystem.dll, which is required."
        exit
    }

    # If we're here, we're definitely installing, so clean any previous versions
    if(Test-Path $InstallPath) {
        del -LiteralPath -rec -for $InstallPath
    }

    mkdir $InstallPath | Out-Null
    $InstallPath = Convert-Path $InstallPath

    [System.IO.Compression.ZipFile]::ExtractToDirectory((Convert-Path $SourcePackage), $InstallPath)

    if($ETag) {
        "$ETag" > (Join-Path $InstallPath ".etag")
    }

    & "$InstallPath\init\init-aspnet-build.ps1"
}

if($List) {
    DoList
} elseif($AddToPath) {
    AddToPath
} elseif($CleanPath) {
    CleanPath
} elseif($GetPath) {
    GetInstallPath $BuildToolsBranch
} else {
    if($PSCmdlet.ParameterSetName -eq "InstallFromPackage") {
        InstallFromPackage
    } elseif($PSCmdlet.ParameterSetName -eq "InstallFromUrl") {
        InstallFromUrl
    } elseif($PSCmdlet.ParameterSetName -eq "InstallFromFeed") {
        $SourceUrl = "$SourceFeed/aspnet-build.$BuildToolsBranch.zip"
        InstallFromUrl
    } elseif($PSCmdlet.ParameterSetName -eq "InstallViaTrainfile") {
        # Load the trainfile and find the URL for the build tools
        if(!(Test-Path $Trainfile)) {
            throw "Trainfile not found: $Trainfile"
        }
        $Trainfile = Convert-Path $Trainfile
        $SourceUrl = cat $Trainfile | where { $_ -match "^BuildTools: (.*)$" } | foreach { $matches[1] }
        Write-Host "Using build tools from Trainfile: $Trainfile"
        InstallFromUrl
    } else {
        throw "Not yet implemented"
    }
}