$Config = @{
    Identifier = 'NetEase.CloudMusic'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri 'https://music.163.com/api/pc/package/download/latest'

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://music.163.com/#/pcupdatelog'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
