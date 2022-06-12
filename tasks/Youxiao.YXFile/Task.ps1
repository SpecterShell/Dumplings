$Config = @{
    Identifier = 'Youxiao.YXFile'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.youxiao.cn/yxfile/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object1.SelectSingleNode('//*[@id="home"]/div/div[1]/form/p[1]/text()[2]').Text.Trim() -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = "https://static.youxiao.cn/yxfile/yxfile_v$($Result.Version).exe"

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.youxiao.cn/index.php/yxfile/log/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="post-930"]/div[2]/ul[1]/li/text()').Text.Trim()
    if ($ReleaseNotesTitle -cmatch [regex]::Escape($Result.Version)) {
        # ReleaseTime
        if ($ReleaseNotesTitle -cmatch '(\d{4}年\d{1,2}月\d{1,2}日)') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="post-930"]/div[2]/ol[1]/li/text()').Text | Format-Text | ConvertTo-OrderedList
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
