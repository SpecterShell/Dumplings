$Config = @{
    Identifier = '115.115Chrome'
    Skip       = $false
    Notes      = 'https://115.com/115/T504444.html'
}

$Ping = {
    $Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.win.version_code

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.win.version_url

    # ReleaseTime
    $Result.ReleaseTime = $Object.data.win.created_time | ConvertFrom-UnixTimeSeconds

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
