$Config = @{
    Identifier = 'EuSoft.Eudic'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://api.frdic.com/api/v2/appsupport/checkversion'
    $Headers = @{
        EudicUserAgent = '/eusoft_eudic_en_win32/12.0.0//'
    }
    $Object = Invoke-RestMethod -Uri $Uri -Headers $Headers

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = 'https://static.frdic.com/pkg/eudic_win.exe'

    # ReleaseTime
    $Result.ReleaseTime = $Object.publish_date | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $ReleaseNotes = $Object.info.Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.eudic.net/v4/en/app/history?appkey=eusoft_eudic_en'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
