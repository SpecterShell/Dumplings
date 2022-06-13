$Config = @{
    Identifier = '360.360SE'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://browser.360.cn/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object1.SelectSingleNode('/html/body/div[3]/p/text()').Text.Trim() -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

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

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="postmessage_118145577"]/strong[3]').InnerText.Trim()
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        if ($ReleaseNotesTitle -cmatch '(\d{4}\.\d{1,2}\.\d{1,2})') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="postmessage_118145577"]/strong[3]/following-sibling::text()[count(.|//*[@id="postmessage_118145577"]/strong[4]/preceding-sibling::text())=count(//*[@id="postmessage_118145577"]/strong[4]/preceding-sibling::text())]').Text | Format-Text
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
