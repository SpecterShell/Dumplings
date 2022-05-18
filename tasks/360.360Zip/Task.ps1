$Config = @{
    'Identifier' = '360.360Zip'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://www.360totalsecurity.com/en/360zip/'
    $Uri2 = 'https://www.360totalsecurity.com/en/download-free-360-zip/'

    $Result = @{}
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Html
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Html

    # Version
    if ($Object1.SelectSingleNode('//*[@id="primary-actions"]/p/span').InnerText -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = 'https:' + $Object2.SelectSingleNode('//*[@id="download-intro"]/div[1]/a').Attributes['href'].Value

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
