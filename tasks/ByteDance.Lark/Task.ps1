$Config = @{
    Identifier = 'ByteDance.Lark'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.larksuite.com/api/downloads'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    if ($Object.versions.Windows.version_number -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.versions.Windows.download_link

    # ReleaseTime
    $Result.ReleaseTime = ConvertFrom-UnixTimeSeconds -Seconds $Object.versions.Windows.release_time

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
