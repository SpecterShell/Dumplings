$Config = @{
    Identifier = 'Yemiao.ZhiyunTranslator'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://free.zhiyunwenxian.cn/zy/UpdateData.txt'
    $Content1 = Invoke-WebRequest -Uri $Uri1 | Get-ResponseContent | ConvertTo-Lf

    $Uri2 = 'https://free.zhiyunwenxian.cn/zy/UpdateURL.txt'
    $Content2 = Invoke-WebRequest -Uri $Uri2 | Get-ResponseContent

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Content1.Split("`n")[0].Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Content2.Trim()

    # ReleaseTime
    if ($Content1 -cmatch '发布日期：(\d{4}年\d{1,2}月\d{1,2}日)') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    if ($Content1 -cmatch '更新内容：.*\n+((?:.+\n)+)') {
        $Result.ReleaseNotes = $Matches[1] | Format-Text
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.wolai.com/xtranslator/vR6osaHKhei3gmhpgNyBj3'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
