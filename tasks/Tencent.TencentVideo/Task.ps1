$Config = @{
    Identifier = 'Tencent.TencentVideo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://v.qq.com/download.html'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[1]').InnerText.Trim(), 'V([\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/a').Attributes['href'].Value

    # ReleaseTime
    if ($Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[3]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[4]/div/ul/li/text()').Text | Format-Text | ConvertTo-OrderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
