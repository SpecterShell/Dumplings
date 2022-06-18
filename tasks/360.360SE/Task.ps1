$Config = @{
    Identifier = '360.360SE'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://browser.360.cn/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.SelectSingleNode('/html/body/div[3]/p/text()').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew"]').Attributes['href'].Value

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://bbs.360.cn/thread-15948589-1-1.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="postmessage_118145577"]/strong[3]').InnerText
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="postmessage_118145577"]/strong[3]/following-sibling::text()[count(.|//*[@id="postmessage_118145577"]/strong[4]/preceding-sibling::text())=count(//*[@id="postmessage_118145577"]/strong[4]/preceding-sibling::text())]').InnerText | Format-Text
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
