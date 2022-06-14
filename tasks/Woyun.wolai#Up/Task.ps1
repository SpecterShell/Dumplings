$Config = @{
    Identifier = 'Woyun.wolai'
    Skip       = $false
    Notes      = @'
升级源
https://www.wolai.com/wolai/k1Qgi1J2L9vWBQkkJz8j82
'@
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
