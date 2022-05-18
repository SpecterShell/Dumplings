$Config = @{
    'Identifier' = 'Yuanli.uTools'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://publish.u-tools.cn/version2/latest.yml'
    $Prefix = 'https://publish.u-tools.cn/version2/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
