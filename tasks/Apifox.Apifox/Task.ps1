$Config = @{
    Identifier = 'Apifox.Apifox'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://cdn.apifox.cn/download/latest.yml?noCache='

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    # InstallerUrl
    $Result.InstallerUrl = $Result.InstallerUrl | ConvertTo-Https

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
