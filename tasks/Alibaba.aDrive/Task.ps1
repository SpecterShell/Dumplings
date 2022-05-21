$Config = @{
    'Identifier' = 'Alibaba.aDrive'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://www.aliyundrive.com/desktop/version/update.json'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = $Object1.url + '/win32/ia32/latest.yml'

    $Result = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
