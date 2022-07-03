$Config = @{
    Identifier = 'Tencent.QQWubi'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'http://qq.pinyin.cn/wubi/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[1]').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[1]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[2]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'http://qq.pinyin.cn/history_wb_pc.php'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'http://qq.pinyin.cn/js/history_info_wb_pc.js'
    $Object2 = Invoke-RestMethod -Uri $Uri2 | Read-EmbeddedJson -StartsFrom 'var pcinfo = ' | ConvertFrom-Json

    $ReleaseNotes = $Object2.vHistory | Where-Object -FilterScript { $_.version.Contains($Result.Version) }
    if ($ReleaseNotes) {
        # ReleaseNotes
        $Result.ReleaseNotes = $ReleaseNotes.version_features | Format-Text
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
