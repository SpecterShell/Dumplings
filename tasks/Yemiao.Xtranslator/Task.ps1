$Config = @{
    'Identifier' = 'Yemiao.Xtranslator'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://free.zhiyunwenxian.cn/xtrans/UpdateData.txt'
    $Uri2 = 'https://free.zhiyunwenxian.cn/xtrans/UpdateURL.txt'

    $Result = [ordered]@{}
    $Content1 = Invoke-WebRequest -Uri $Uri1 | Get-ResponseContent
    $Content2 = Invoke-WebRequest -Uri $Uri2 | Get-ResponseContent

    # Version
    $Result.Version = $Content1.Split("`r`n")[0].Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Content2.Trim()

    # ReleaseTime
    if ($Content1 -cmatch '发布日期：([\d/]+)') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    if ($Content1 -cmatch '更新日志：.*(?:\n)+((?:.+\n)+)') {
        $Result.ReleaseNotes = $Matches[1] | Format-Text
    }

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
