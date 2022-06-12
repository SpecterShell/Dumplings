$Config = @{
    Identifier = 'Alibaba.Teambition'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
