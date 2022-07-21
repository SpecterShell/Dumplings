$Config = @{
    Identifier = 'Wondershare.Fotophire.Toolkit'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 3316 -Version '1.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire_full3316.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
