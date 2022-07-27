$Config = @{
    Identifier = 'ByteDance.Douyin'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Uri = 'https://www.douyin.com/downloadpage/pc'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[2]').InnerText.Trim(),
        '最新版本：([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[1]/a[1]').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="root"]/div/div[2]/div/div[3]/div/div[1]/div/div/div[2]').InnerText.Trim(),
        '更新时间：(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
