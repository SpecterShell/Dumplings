$Config = @{
    Identifier = 'Axure.AxureRP.10'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.axure.com/update-check/CheckForUpdate?info=%7B%22ClientVersion%22%3A%2210.0.0.0000%22%2C%22ClientOS%22%3A%22Windows%7C64bit%22%7D'
    $Content = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    if ($Content -cmatch 'id=([\d]+)') {
        $Version = $Matches[1]
        $Result.Version = "10.0.0.${Version}"
    }

    # InstallerUrl
    $Result.InstallerUrl = "https://axure.cachefly.net/versions/10-0/AxureRP-Setup-${Version}.exe"

    # ReleaseTime
    if ($Content -cmatch 'subtitle=(\d{1,2}/\d{1,2}/\d{4})') {
        $Result.ReleaseTime = [datetime]::Parse($Matches[1], [cultureinfo]::GetCultureInfo('en-US')).ToString('yyyy-MM-dd')
    }

    # ReleaseNotes
    if ($Content -cmatch '(?s)message=(.+)') {
        $ReleaseNotes = $Matches[1].Split('<title>')[1].Split("`n")
        $Result.ReleaseNotes = $ReleaseNotes[3..($ReleaseNotes.Length - 1)] | Format-Text
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.axure.com/release-history'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
