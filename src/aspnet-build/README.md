# aspnet-build

Launcher for MSBuild. Simple wrapper that when published produces a runnable artifact that launches MSBuild.

## Usage

1. `dotnet publish`
2. `dotnet path/to/publish/output/aspnet-build.dll [msbuild args]`