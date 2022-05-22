$Config = @{
    'Identifier' = 'Alibaba.Teambition'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://im.dingtalk.com/manifest/dtron/Teambition/win32/ia32/latest.yml'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
