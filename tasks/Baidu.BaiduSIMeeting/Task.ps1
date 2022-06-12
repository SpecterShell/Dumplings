$Config = @{
    Identifier = 'Baidu.BaiduSIMeeting'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://fanyiapp.cdn.bcebos.com/tongchuan/update/latest.yml'
    $Prefix = 'https://fanyiapp.cdn.bcebos.com/tongchuan/update/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
