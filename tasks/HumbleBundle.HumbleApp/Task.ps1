$Config = @{
    Identifier = 'HumbleBundle.HumbleApp'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.humblebundle.com/client/update/NGf0YgSs2uKIyI4dFQIU/latest.yml'
    $Prefix = 'https://www.humblebundle.com/client/update/NGf0YgSs2uKIyI4dFQIU/'

    $Result = Invoke-WebRequest -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
