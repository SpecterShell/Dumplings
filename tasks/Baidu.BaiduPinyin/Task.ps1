$Config = @{
    'Identifier' = 'Baidu.BaiduPinyin'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://shurufa.baidu.com/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Uri2 = 'https://shurufa.baidu.com/update'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="downloadInfo"]/div[1]/a').Attributes['href'].Value

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1]
    }

    # ReleaseTime
    if ($Object1.SelectSingleNode('//*[@id="versionMsg"]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="update_body"]/div/div/div[1]/span[2]').InnerText.Trim()
    if ($ReleaseNotesTitle -cmatch [regex]::Escape($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@class="update-item-split"][1]/following::*[@class="update-item-con"][count(.|//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])=count(//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])]').SelectNodes('p|div').InnerText | Format-Text
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
