$Config = @{
    Identifier = '115.115Chrome'
    Skip       = $false
    Note       = 'https://115.com/115'
}

$Ping = {
    $Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.window_115.version_code

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.window_115.version_url

    # ReleaseTime
    $Result.ReleaseTime = ConvertFrom-UnixTimeSeconds -Seconds $Object.data.window_115.created_time

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
