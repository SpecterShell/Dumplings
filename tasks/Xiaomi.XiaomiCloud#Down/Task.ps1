$Config = @{
    Identifier = 'Xiaomi.XiaomiCloud'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Uri = 'https://update-server.micloud.xiaomi.net/api/v1/releases'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.data.winx64

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
