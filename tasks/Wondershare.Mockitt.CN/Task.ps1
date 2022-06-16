$Config = @{
    Identifier = 'Wondershare.Mockitt.CN'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://modao.cc/api/v2/client/desktop/check_update.json?region=CN&version=1.1.0&platform=win32&arch=x64'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://cdn.modao.cc/Mockitt-win32-ia32-zh-$($Result.Version).exe",
        "https://cdn.modao.cc/Mockitt-win32-x64-zh-$($Result.Version).exe"
    )

    # ReleaseTime
    $Result.ReleaseTime = $Object.pub_date.ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.release_notes_zh | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://modao.cc/changelog'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
