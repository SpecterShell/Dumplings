$Config = @{
    Identifier = 'Wondershare.HiPDF'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 7411 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/hipdf-desktop_full7411.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
