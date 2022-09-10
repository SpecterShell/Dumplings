$Config = @{
    Identifier = 'Huawei.HiSuite'
    Skip       = $false
    Notes      = '国际版下载源'
}

$Ping = {
    $Uri = 'https://consumer.huawei.com/en/support/hisuite/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('/html/body/div[6]/div/div/div[1]/div[1]/div[2]/p[1]/span[1]').InnerText,
        'V([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('/html/body/div[6]/div/div/div[1]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('/html/body/div[6]/div/div/div[1]/div[1]/div[2]/p[1]/span[1]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
