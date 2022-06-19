$Config = @{
    Identifier = 'DigiDNA.iMazing'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://downloads.imazing.com/com.DigiDNA.iMazing2Windows.xml'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1[0].enclosure.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1[0].enclosure.url

    # ReleaseTime
    $Result.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object1[0].releaseNotesLink

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Object2 = Invoke-WebRequest -Uri $Result.ReleaseNotesUrl | ConvertFrom-Html

    if ($Object2.SelectSingleNode("/html/body/div/*[contains(text(), '$($Result.Version)')]").InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectSingleNode("/html/body/div/*[contains(text(), '$($Result.Version)')]/following-sibling::ul").InnerText | Format-Text | ConvertTo-UnorderedList
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
