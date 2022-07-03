$Config = @{
    Identifier = 'Tencent.QQPinyin'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Uri = 'http://config.android.qqpy.sogou.com/update?fr=pypc'
    $Body = @{
        'CSoftID'     = 14
        'CVer'        = '6.2.5507.400'
        'Cmd'         = 1
        'GUID'        = '000000000'
        'TriggerMode' = 4
    } | ConvertTo-Json -Compress
    $Object = Invoke-RestMethod -Uri $Uri -Method Post -Body $Body

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.NewVer

    # InstallerUrl
    $Result.InstallerUrl = $Object.DownloadUrl

    # ReleaseNotes
    $ReleaseNotes = ($Object.Desp.Replace("`r", "`n") | Format-Text).Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] -join "`n"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'http://qq.pinyin.cn/history_pc.php'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
