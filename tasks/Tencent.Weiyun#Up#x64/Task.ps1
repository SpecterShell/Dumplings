$Config = @{
    Identifier = 'Tencent.Weiyun'
    Skip       = $false
    Notes      = '升级源 64 位'
}

$Ping = {
    $Uri = 'https://dldir1.qq.com/weiyun/electron-update/release/x64/latest.yml'
    $Prefix = 'https://dldir1.qq.com/weiyun/electron-update/release/x64/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
