$Config = @{
    Identifier = 'Wondershare.DemoCreator.CN'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 13164 -Version '5.2.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/democreator_$($Result.Version)_full13164.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
