$Config = @{
    'Identifier' = 'Hitencent.JisuPDFEditor'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://www.jisupdfeditor.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[1]').InnerText.Trim() -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/a').Attributes['href'].Value

    # ReleaseTime
    if ($Object.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[2]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
