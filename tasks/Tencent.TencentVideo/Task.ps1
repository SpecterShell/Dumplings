$Config = @{
    Identifier = 'Tencent.TencentVideo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://v.qq.com/download.html'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[1]').InnerText,
        'V([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[3]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[4]/div/ul/li/text()').InnerText | Format-Text | ConvertTo-OrderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
