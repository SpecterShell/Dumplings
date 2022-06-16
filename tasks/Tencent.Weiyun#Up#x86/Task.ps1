$Config = @{
    Identifier = 'Tencent.Weiyun'
    Skip       = $false
    Notes      = '升级源 32 位'
}

$Ping = {
    $Uri = 'https://dldir1.qq.com/weiyun/electron-update/release/win32/latest-win32.yml'
    $Prefix = 'https://dldir1.qq.com/weiyun/electron-update/release/win32/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
