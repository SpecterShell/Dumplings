$Config = @{
    'Identifier' = '360.PalmInput'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://cdn.soft.360.cn/static/baoku/info_7_0/softinfo_104126128.html'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[2]/span[2]').InnerText.Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="download_btn"]').Attributes['data-downurl'].Value

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[4]/span[2]').InnerText.Trim() -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="doc"]/div[3]/div[3]/div[2]/div/p/text()').Text | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
