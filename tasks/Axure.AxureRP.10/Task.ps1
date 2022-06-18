$Config = @{
    Identifier = 'Axure.AxureRP.10'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.axure.com/update-check/CheckForUpdate?info=%7B%22ClientVersion%22%3A%2210.0.0.0000%22%2C%22ClientOS%22%3A%22Windows%7C64bit%22%7D'
    $Content = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Version = [regex]::Match($Content, 'id=([\d]+)').Groups[1].Value
    $Result.Version = "10.0.0.${Version}"

    # InstallerUrl
    $Result.InstallerUrl = "https://axure.cachefly.net/versions/10-0/AxureRP-Setup-${Version}.exe"

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Content, 'subtitle=(\d{1,2}/\d{1,2}/\d{4})').Groups[1].Value,
        'M/d/yyyy',
        $null
    ).ToString('yyyy-MM-dd')

    # ReleaseNotes
    $ReleaseNotes = [regex]::Match($Content, '(?s)message=(.+)').Groups[1].Value.Split('<title>')[1].Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[2..($ReleaseNotes.Length - 1)] | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.axure.com/release-history'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
