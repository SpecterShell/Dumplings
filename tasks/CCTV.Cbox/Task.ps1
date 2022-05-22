$Config = @{
    'Identifier' = 'CCTV.Cbox'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://download.cntv.cn/cbox/update_config.txt'
    $Object = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.update_url

    # Version
    if ($Result.InstallerUrl -cmatch '_v([\d\.]+)_') {
        $Result.Version = $Matches[1]
    }

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.status.now | ConvertTo-UtcDateTime -Id 'China Standard Time'

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
