$Config = @{
    Identifier = 'Ximalaya.XimalayaLive'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/latest.yml'
    $Prefix = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
