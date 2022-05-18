$Config = @{
    'Identifier' = 'Youxiao.YXFile'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://www.youxiao.cn/yxfile/'
    $Uri2 = 'https://www.youxiao.cn/index.php/yxfile/log/'

    $Result = @{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # Version
    if ($Object1.SelectSingleNode('//*[@id="home"]/div/div[1]/form/p[1]/text()[2]').Text -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = "https://static.youxiao.cn/yxfile/yxfile_v$($Result.Version).exe"

    # ReleaseTime
    if ($Object2.SelectSingleNode('//*[@id="post-930"]/div[2]/ul[1]/li/text()').Text -cmatch '(\d{4}年\d{1,2}月\d{1,2}日)') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="post-930"]/div[2]/ol[1]/li/text()').Text | ConvertTo-OrderedList | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
