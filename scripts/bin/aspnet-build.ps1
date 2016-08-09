$Root = Split-Path -Parent $PSScriptRoot
$DotNet="$Root\dotnet-cli\dotnet.exe"
$DefaultMakefile = "$Root\Microsoft.AspNetCore.Build\msbuild\DefaultMakefile.proj"

if(!(Test-Path $DotNet))
{
    throw "error: Tools have not been initialized yet. Run the init-aspnet-build.ps1 script in the build tools."
}

$chdir = $null

function GetMakefileFor($dir) {
    $chdir = $dir
    $candidate = Join-Path $dir "makefile.proj"
    if(Test-Path $candidate) {
        $candidate
    } else {
        $DefaultMakefile
    }
}

# Scan the args to identify if we're build a project or repo
$sawProject = $false
$newArgs = $args | ForEach {
    if($_.StartsWith("/") -or $_.StartsWith("-")) {
        # Pass through all switches
        $_
    }
    else {
        $sawProject = $true
        if(Test-Path $_) {
            # It's a thing that exists :). But is it a project or a directory?
            $item = Get-Item $_
            if($item.PSIsContainer) {
                # It's a directory, treat it as an ASP.NET Repo
                GetMakefileFor $_
            } else {
                # It's a file, let it pass through
                $_
            }
        }
    }
}

if(!$sawProject) {
    $newArgs = @(GetMakefileFor .) + $newArgs
}

$newArgs += @("/p:AspNetBuildRoot=$Root")

$oldPath = $env:PATH
try {
    $env:PATH="$(Split-Path -Parent $DotNet);$env:PATH"
    Write-Host "> dotnet build3 $newArgs"
    if($chdir) {
        pushd $chdir
        try {
            & "$DotNet" build3 @newArgs
        } finally {
            popd
        }
    } else {
        & "$DotNet" build3 @newArgs
    }
} finally {
    $env:PATH = $oldPath
}