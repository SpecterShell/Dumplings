$Config = @{
    Identifier = 'Yemiao.ZhiyunTranslator'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://free.zhiyunwenxian.cn/zy/UpdateData.txt'
    $Content1 = Invoke-WebRequest -Uri $Uri1 | Read-ResponseContent | ConvertTo-Lf

    $Uri2 = 'https://free.zhiyunwenxian.cn/zy/UpdateURL.txt'
    $Content2 = Invoke-WebRequest -Uri $Uri2 | Read-ResponseContent

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Content1.Split("`n")[0].Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Content2.Trim()

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($Content1, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = [regex]::Match($Content1, '更新内容：.*\n+((?:.+\n)+)').Groups[1].Value | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.wolai.com/xtranslator/vR6osaHKhei3gmhpgNyBj3'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
