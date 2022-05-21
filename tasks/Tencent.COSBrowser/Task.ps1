$Config = @{
    'Identifier' = 'Tencent.COSBrowser'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://cos5.cloud.tencent.com/cosbrowser/latest.yml'
    $Prefix = 'https://cos5.cloud.tencent.com/cosbrowser/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
