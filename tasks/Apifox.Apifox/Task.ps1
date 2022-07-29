$Config = @{
    Identifier = 'Apifox.Apifox'
    Skip       = $true
}

$Ping = {
    $Uri = 'https://cdn.apifox.cn/download/latest.yml'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    # InstallerUrl
    $Result.InstallerUrl = $Result.InstallerUrl | ConvertTo-Https

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
