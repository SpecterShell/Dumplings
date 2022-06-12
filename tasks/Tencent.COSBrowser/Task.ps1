$Config = @{
    Identifier = 'Tencent.COSBrowser'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://cos5.cloud.tencent.com/cosbrowser/latest.yml'
    $Prefix = 'https://cos5.cloud.tencent.com/cosbrowser/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
