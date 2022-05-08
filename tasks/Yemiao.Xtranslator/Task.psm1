$Config = @{
    'Identifier' = 'Yemiao.Xtranslator'
    'Skip'       = $false
}

$Uri1 = 'https://free.zhiyunwenxian.cn/xtrans/UpdateData.txt'
$Uri2 = 'https://free.zhiyunwenxian.cn/xtrans/UpdateURL.txt'

$Fetch = {
    $Result = [PSCustomObject]@{}
    $Content1 = Invoke-WebRequest -Uri $Uri1 | Get-ResponseContent
    $Content2 = Invoke-WebRequest -Uri $Uri2 | Get-ResponseContent

    # Version
    $Version = $Content1.Split("`r`n")[0].Trim()
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Version -InputObject $Result

    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $Content2.Trim() -InputObject $Result

    # ReleaseTime
    if ($Content1 -cmatch '发布日期：([\d/]+)') {
        $ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $ReleaseTime -InputObject $Result
    }

    # ReleaseNotes
    if ($Content1 -cmatch '更新日志：.*(?:\n)+((?:.+\n)+)') {
        $ReleaseNotes = $Matches[1] | Format-Text
        Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value $ReleaseNotes -InputObject $Result
    }

    return $Result
}

Export-ModuleMember -Variable Config, Fetch
