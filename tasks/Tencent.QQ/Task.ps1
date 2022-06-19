$Config = @{
    Identifier = 'Tencent.QQ'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://im.qq.com/download'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="imedit_wordandurl_pctabdownurl"]').Attributes['href'].Value

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="imedit_date_pctab"]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="imedit_list_pctab"]/li').InnerText | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://im.qq.com/pcqq/logs'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
