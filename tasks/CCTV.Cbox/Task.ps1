$Config = @{
    Identifier = 'CCTV.Cbox'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://download.cntv.cn/cbox/update_config.txt'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.update_url

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '_v([\d\.]+)_').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.status.now | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
