param($StorageConnectionString, $PackagePath)

if(!(Test-Path $PackagePath)) {
    throw "Can't find package $PackagePath"
}
$PackagePath = Convert-Path $PackagePath

$ContainerName = "aspnetbuildpackages"
$FileName = Split-Path -Leaf $PackagePath

$Context = New-AzureStorageContext -ConnectionString $StorageConnectionString

$Container = Get-AzureStorageContainer -Name $ContainerName -ErrorAction SilentlyContinue -Context $Context
if(!$Container) {
    New-AzureStorageContainer -Context $Context -Name $ContainerName -Permission Blob
}

Set-AzureStorageBlobContent -Force -Context $Context -File $PackagePath -Blob $FileName -Container $ContainerName