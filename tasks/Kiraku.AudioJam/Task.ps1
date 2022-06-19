$Config = @{
    Identifier = 'Kiraku.AudioJam'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://api.kirakuapp.com/auth/version/latest?appId=4&platform=0'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.versionCode

    # InstallerUrl
    $Result.InstallerUrl = [uri]::UnescapeDataString($Object.data.downloadUrl)

    # ReleaseTime
    $Result.ReleaseTime = $Object.data.createTime | ConvertFrom-UnixTimeMilliseconds

    # ReleaseNotes
    $Result.ReleaseNotes = @()
    $ReleaseNotes = $Object.data.updateLog | ConvertFrom-Json
    if ($ReleaseNotes.added) {
        $Result.ReleaseNotes += $ReleaseNotes.added -creplace '^', '[+ADDED] '
    }
    if ($ReleaseNotes.changed) {
        $Result.ReleaseNotes += $ReleaseNotes.changed -creplace '^', '[*CHANGED] '
    }
    if ($ReleaseNotes.fixed) {
        $Result.ReleaseNotes += $ReleaseNotes.fixed -creplace '^', '[-FIXED] '
    }
    $Result.ReleaseNotes = $Result.ReleaseNotes -join "`n"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
