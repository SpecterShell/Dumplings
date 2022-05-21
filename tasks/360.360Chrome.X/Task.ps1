$Config = @{
    'Identifier' = '360.360Chrome.X'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://browser.360.cn/ee/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Uri2 = 'https://bbs.360.cn/thread-16005307-1-1.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew64"]').Attributes['href'].Value

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1]
    }

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="postmessage_118543728"]/strong[6]').InnerText.Trim()
    if ($ReleaseNotesTitle -cmatch [regex]::Escape($Result.Version)) {
        # ReleaseTime
        if ($ReleaseNotesTitle -cmatch '(\d{4}\.\d{1,2}\.\d{1,2})') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="postmessage_118543728"]/strong[6]/following-sibling::text()[count(.|//*[@id="postmessage_118543728"]/strong[7]/preceding-sibling::text())=count(//*[@id="postmessage_118543728"]/strong[7]/preceding-sibling::text())]').Text | Format-Text
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
