$Config = @{
    'Identifier' = 'PaodingAI.PDFlux'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://pdflux.com/downloads/latest.yml'
    $Prefix = 'https://pdflux.com/downloads/'

    $Uri2 = 'https://pdflux.com/log/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Get-ResponseContent | ConvertFrom-Html

    $Result = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    # ReleaseNotes
    if ($Object2.SelectSingleNode('//*[@class="last-version"]//*[@class="version-title"]').InnerText.Trim() -cmatch '([\d\.]+)') {
        $Result.ReleaseNotes = $Object2.SelectSingleNode('//*[@class="last-version"]//*[@class="version-subtitle"]').InnerText | Format-Text | ConvertTo-OrderedList
    }

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
