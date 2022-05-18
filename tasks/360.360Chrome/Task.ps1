$Config = @{
    'Identifier' = '360.360Chrome'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://browser.360.cn/ee/'
    $Uri2 = 'https://bbs.360.cn/thread-15913525-1-1.html'

    $Result = [ordered]@{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew"]').Attributes['href'].Value

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1].Trim()
    }

    # ReleaseTime
    if ($Object2.SelectSingleNode('//*[@id="postmessage_117915619"]/strong[1]').InnerText -cmatch '(\d{4}年\d{1,2}月\d{1,2}日)') {
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
