$Config = @{
    Identifier = 'Thunisoft.HuayuPY'
    Skip       = $false
    Notes      = @'
下载源（版本、地址、日期）+网页源（内容）
http://bbs.pinyin.thunisoft.com/forum.php?mod=forumdisplay&fid=2
'@
}

$Ping = {
    $Uri1 = 'https://pinyin.thunisoft.com/webapi/v1/setup/setupinfo?os=win'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.result.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.result.addr

    # ReleaseTime
    $Result.ReleaseTime = $Object1.result.date | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://pinyin.thunisoft.com/webapi/v1/version/getpublishupdatelog'
    $Object2 = (Invoke-RestMethod -Uri $Uri2).result | Where-Object -Property version -EQ -Value $Result.Version

    if ($Object2) {
        # ReleaseNotes
        $ReleaseNotes = $Object2.newfeature.Split("`n")
        $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] | Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
