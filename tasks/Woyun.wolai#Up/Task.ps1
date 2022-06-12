$Config = @{
    Identifier = 'Woyun.wolai'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://static2.wolai.com/dist/installers/latest.yml'
    $Prefix = 'https://cdn.wostatic.cn/dist/installers/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
