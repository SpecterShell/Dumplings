$Config = @{
    Identifier = 'YouXiao.YXFile'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.youxiao.cn/yxfile/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="home"]/div/div[1]/form/p[1]/text()[2]').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

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

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="post-930"]/div[2]/ul[1]/li/text()').InnerText
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="post-930"]/div[2]/ol[1]/li/text()').InnerText | Format-Text | ConvertTo-OrderedList
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
