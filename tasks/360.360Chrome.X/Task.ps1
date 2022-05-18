$Config = @{
    'Identifier' = '360.360Chrome.X'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://browser.360.cn/ee/'
    $Uri2 = 'https://bbs.360.cn/thread-16005307-1-1.html'

    $Result = @{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew64"]').Attributes['href'].Value

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1].Trim()
    }

    # ReleaseTime
    if ($Object2.SelectSingleNode('//*[@id="postmessage_118543728"]/strong[6]').InnerText -cmatch '(\d{4}\.\d{1,2}\.\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
