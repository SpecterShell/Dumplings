$Config = @{
    Identifier = 'Kingsoft.WPSOffice.CN'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://platform.wps.cn/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="nav"]/div/div/a[2]').Attributes['href'].Value

    # Version
    $Result.Version = '11.1.0.' + [regex]::Match($Result.InstallerUrl, 'WPS_Setup_(\d+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="intro"]/div[2]/div[1]/div[2]/div[1]/span[1]/text()').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
