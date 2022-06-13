$Config = @{
    Identifier = 'Yuanli.uTools'
    Skip       = $false
    Notes      = 'https://yuanliao.info/t/utools'
}

$Ping = {
    $Uri = 'https://publish.u-tools.cn/version2/latest.yml'
    $Prefix = 'https://publish.u-tools.cn/version2/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
