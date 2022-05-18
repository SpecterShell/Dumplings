$Config = @{
    'Identifier' = '360.PalmInput'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://baoku.360.cn/soft/show/appid/104126128'
    $Uri2 = 'https://cdn.soft.360.cn/static/baoku/info_7_0/softinfo_104126128.html'

    $Result = @{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # Version
    if ($Object1.SelectSingleNode('/html/body/div[2]/div[2]/div/div[2]/div/div[2]/div[1]/span[2]').InnerText -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('/html/body/div[2]/div[2]/div/div[4]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object1.SelectSingleNode('/html/body/div[2]/div[2]/div/div[2]/div/div[2]/div[2]/span[2]').InnerText.Trim()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="doc"]/div[3]/div[3]/div[2]/div/p/text()').Text | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
