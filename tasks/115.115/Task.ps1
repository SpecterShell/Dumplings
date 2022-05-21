$Config = @{
    'Identifier' = '115.115'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.win.version_code

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.win.version_url

    # ReleaseTime
    $Result.ReleaseTime = ConvertFrom-UnixTimeSeconds -Seconds $Object.data.win.created_time

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
