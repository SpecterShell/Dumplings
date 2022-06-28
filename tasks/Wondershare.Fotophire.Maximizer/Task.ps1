$Config = @{
    Identifier = 'Wondershare.Fotophire.Maximizer'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 3313 -Version '1.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-maximizer_full3313.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
