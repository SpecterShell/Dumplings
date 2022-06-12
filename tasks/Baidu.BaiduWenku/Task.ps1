$Config = @{
    Identifier = 'Baidu.BaiduWenku'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://edu-wenku.bdimg.com/v1/pcclient/upgrade/latest.yml'
    $Prefix = 'https://edu-wenku.bdimg.com/v1/pcclient/upgrade/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
