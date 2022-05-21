$Config = @{
    'Identifier' = 'PaodingAI.PDFlux'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://pdflux.com/downloads/latest.yml'
    $Prefix = 'https://pdflux.com/downloads/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix
    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
