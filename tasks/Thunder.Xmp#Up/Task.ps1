$Config = @{
    Identifier = 'Thunder.Xmp'
    Skip       = $true
    Notes      = '升级源'
}

$Ping = {
    $Uri = 'http://upgrade.xl9.xunlei.com/pc?pid=2&cid=100039&v=3.3.1.6050&os=10&t=2&lng=0804'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.v

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.url.Replace('xmpup', 'xmp')

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.data.desc | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'http://video.xunlei.com/pc_history.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
