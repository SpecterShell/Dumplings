$Config = @{
    Identifier = 'Wondershare.MobileTrans'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 5793 -Version '1.0.0.0' -X86

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/mobiletrans_$($Result.Version)_full5793.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
