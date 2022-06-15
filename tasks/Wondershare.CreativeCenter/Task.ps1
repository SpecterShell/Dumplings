$Config = @{
    Identifier = 'Wondershare.CreativeCenter'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 10819 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/wondershareCC_$($Result.Version)_full10819.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
