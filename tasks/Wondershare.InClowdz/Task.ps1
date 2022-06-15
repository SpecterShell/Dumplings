$Config = @{
    Identifier = 'Wondershare.InClowdz'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 7920 -Wae '3.0.1'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/inclowdz_full7920.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
