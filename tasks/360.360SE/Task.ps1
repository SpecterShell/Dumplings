$Config = @{
    'Identifier' = '360.360SE'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://browser.360.cn/'
    $Uri2 = 'https://bbs.360.cn/thread-15948589-1-1.html'

    $Result = [ordered]@{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # Version
    if ($Object1.SelectSingleNode('/html/body/div[3]/p/text()').Text -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew"]').Attributes['href'].Value

    # ReleaseTime
    if ($Object2.SelectSingleNode('//*[@id="postmessage_118145577"]/strong[3]').InnerText -cmatch '(\d{4}\.\d{1,2}\.\d{1,2})') {
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
