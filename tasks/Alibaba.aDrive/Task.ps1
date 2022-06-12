$Config = @{
    Identifier = 'Alibaba.aDrive'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.aliyundrive.com/desktop/version/update.json'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = $Object1.url + '/win32/ia32/latest.yml'

    $Result = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
