$Config = @{
    'Identifier' = 'Yuanli.uTools'
    'Skip'       = $false
}

$Uri = 'https://publish.u-tools.cn/version2/latest.yml'
$Prefix = 'https://publish.u-tools.cn/version2/'

$Fetch = {
    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return $Result
}

Export-ModuleMember -Variable Config, Fetch
