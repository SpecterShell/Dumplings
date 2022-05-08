$Config = @{
    'Identifier' = 'Youxiao.YXFile'
    'Skip'       = $false
}

$Uri1 = 'https://www.youxiao.cn/yxfile/'
$Uri2 = 'https://www.youxiao.cn/index.php/yxfile/log/'

$Fetch = {
    $Result = [PSCustomObject]@{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # Version
    if ($Object1.SelectSingleNode('//*[@id="home"]/div/div[1]/form/p[1]/text()[2]').Text -cmatch '([\d\.]+)') {
        $Version = $Matches[1].Trim()
        Add-Member -MemberType NoteProperty -Name 'Version' -Value $Version -InputObject $Result
    }

    # InstallerUrls
    $InstallerUrl = "https://static.youxiao.cn/yxfile/yxfile_v${Version}.exe"
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $InstallerUrl -InputObject $Result

    # ReleaseTime
    if ($Object2.SelectSingleNode('//*[@id="post-930"]/div[2]/ul[1]/li/text()').Text -cmatch '(\d{4}年\d{1,2}月\d{1,2}日)') {
        $ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $ReleaseTime -InputObject $Result
    }

    # ReleaseNotes
    $ReleaseNotes = $Object2.SelectNodes('//*[@id="post-930"]/div[2]/ol[1]/li/text()').Text | ConvertTo-OrderedList | Format-Text
    Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value $ReleaseNotes -InputObject $Result

    # ReleaseNotesUrl
    Add-Member -MemberType NoteProperty -Name 'ReleaseNotesUrl' -Value $Uri2 -InputObject $Result

    return $Result
}

Export-ModuleMember -Variable Config, Fetch
