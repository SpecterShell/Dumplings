$Config = @{
    'Identifier' = 'HumbleBundle.HumbleApp'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://www.humblebundle.com/client/update/NGf0YgSs2uKIyI4dFQIU/latest.yml'
    $Prefix = 'https://www.humblebundle.com/client/update/NGf0YgSs2uKIyI4dFQIU/'

    $Result = Invoke-WebRequest -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
