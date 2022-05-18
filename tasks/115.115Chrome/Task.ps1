$Config = @{
    'Identifier' = '115.115Chrome'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri

    # Version
    $Result.Version = $Object.data.window_115.version_code

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.window_115.version_url

    # ReleaseTime
    $Result.ReleaseTime = ($Object.data.window_115.created_time | ConvertFrom-UnixTimeSeconds)

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
