$Config = @{
    'Identifier' = 'Woyun.wolai'
    'Skip'       = $false
}

$Uri = 'https://static2.wolai.com/dist/installers/latest.yml'
$Prefix = 'https://cdn.wostatic.cn/dist/installers/'

$Fetch = {
    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return $Result
}

Export-ModuleMember -Variable Config, Fetch
