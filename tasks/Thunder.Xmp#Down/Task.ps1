$Config = @{
    Identifier = 'Thunder.Xmp'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Uri = 'https://static-xl.a.88cdn.com/json/xunlei_video_version_pc.json'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.url | ConvertTo-Https

    # ReleaseTime
    $Result.ReleaseTime = $Object.update_time | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.content | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'http://video.xunlei.com/pc_history.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
