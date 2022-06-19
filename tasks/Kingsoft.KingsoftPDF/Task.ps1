$Config = @{
    Identifier = 'Kingsoft.KingsoftPDF'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.wps.cn/product/kingsoftpdf'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('/html/body/div[1]/div/div[2]/p').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('/html/body/div[1]/div/div[2]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//html/body/div[1]/div/div[2]/p').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
