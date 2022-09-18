$Config = @{
    Identifier = 'NetEase.CloudMusic'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Object = Invoke-CloudMusicApi -Path '/pc/upgrade/get' -Params @{
        'e_r' = $false
        'action' = 'manual'
    }

    $Result = [ordered]@{}

    if (-not $Object.data.packageVO) {
        throw 'The server returns nothing'
    }

    # Version
    $Result.Version = "$($Object.data.packageVO.appver).$($Object.data.packageVO.buildver)"

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.packageVO.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.data.upgradeContent | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://music.163.com/#/pcupdatelog'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
