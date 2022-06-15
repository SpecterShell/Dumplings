$Config = @{
    Identifier = 'Thunisoft.HuayuPY'
    Skip       = $false
    Notes      = @'
升级源（版本、地址）+网页源（内容、日期）
http://bbs.pinyin.thunisoft.com/forum.php?mod=forumdisplay&fid=2
'@
}

$Ping = {
    $Uri1 = 'https://pinyin.thunisoft.com/manuapi/v1/update?version=0&os=win&cpu=x86&frame=tsf'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.result.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.result.addr

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
        # ReleaseTime
        $Result.ReleaseTime = Get-Date -Date $Object2.time -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $ReleaseNotes = $Object2.newfeature.Split("`n")
        $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] | Format-Text
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
