$Config = @{
    Identifier = 'JinweiZhiguang.MasterGo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://static-nc.mastergo.com/plugins/desktop/windows/latest.yml'
    $Prefix = 'https://static-nc.mastergo.com/plugins/desktop/windows/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
