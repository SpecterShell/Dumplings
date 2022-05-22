$Config = @{
    'Identifier' = 'Baidu.BaiduWenku'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://edu-wenku.bdimg.com/v1/pcclient/upgrade/latest.yml'
    $Prefix = 'https://edu-wenku.bdimg.com/v1/pcclient/upgrade/'

    $Result = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
