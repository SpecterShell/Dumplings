$Config = @{
    Identifier = 'PaodingAI.PDFlux'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://pdflux.com/downloads/latest.yml'
    $Prefix = 'https://pdflux.com/downloads/'

    $Result = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://pdflux.com/log/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Read-ResponseContent | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@class="last-version"]//*[@class="version-title"]').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectSingleNode('//*[@class="last-version"]//*[@class="version-subtitle"]').InnerText | Format-Text | ConvertTo-OrderedList
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
