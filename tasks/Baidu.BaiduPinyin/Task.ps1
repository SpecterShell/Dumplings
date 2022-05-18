$Config = @{
    'Identifier' = 'Baidu.BaiduPinyin'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://shurufa.baidu.com/'
    $Uri2 = 'https://shurufa.baidu.com/update'

    $Result = [ordered]@{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="downloadInfo"]/div[1]/a').Attributes['href'].Value

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1].Trim()
    }

    # ReleaseTime
    if ($Object1.SelectSingleNode('//*[@id="versionMsg"]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
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
