$Config = @{
    Identifier = 'Hitencent.JisuPDFToWord'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc.jisupdftoword.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/p/text()[1]').InnerText,
        'V([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="bd"]/div/div[1]/div[2]/p/text()[2]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
