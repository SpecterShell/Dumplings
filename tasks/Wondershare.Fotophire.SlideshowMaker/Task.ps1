$Config = @{
    Identifier = 'Wondershare.Fotophire.SlideshowMaker'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 4583 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-slideshow-maker_full4583.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
