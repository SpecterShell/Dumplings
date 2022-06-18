$Config = @{
    Identifier = 'Woyun.wolai'
    Skip       = $false
    Notes      = @'
下载源
https://www.wolai.com/wolai/k1Qgi1J2L9vWBQkkJz8j82
'@
}

$Ping = {
    $Uri = 'https://cdn.wostatic.cn/dist/installers/electron-versions.json'
    $Prefix = 'https://cdn.wostatic.cn/dist/installers/'

    $Result = (Invoke-RestMethod -Uri $Uri).win | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
