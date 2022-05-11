$Config = @{
    'Identifier' = 'Yuanli.uTools'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://publish.u-tools.cn/version2/latest.yml'
    $Prefix = 'https://publish.u-tools.cn/version2/'

    $Result = Invoke-RestMethod @WebRequestParameters -Uri $Uri | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return $Result
}

return [PSCustomObject]@{Config = $Config; Fetch = $Fetch }
