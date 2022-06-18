$Config = @{
    Identifier = 'Baidu.BaiduPinyin'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://shurufa.baidu.com/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="downloadInfo"]/div[1]/a').Attributes['href'].Value

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="versionMsg"]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://shurufa.baidu.com/update'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@id="update_body"]/div/div/div[1]/span[2]').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@class="update-item-split"][1]/following::*[@class="update-item-con"][count(.|//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])=count(//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])]').SelectNodes('p|div').InnerText | Format-Text
    }
    else {
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
