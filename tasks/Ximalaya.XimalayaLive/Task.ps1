$Config = @{
    'Identifier' = 'Ximalaya.XimalayaLive'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/latest.yml'
    $Prefix = 'https://s1.xmcdn.com/yx/xmly-live-release/last/dist/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
