$Config = @{
    Identifier = 'Wondershare.Fotophire.Focus'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 3314 -Version '1.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/fotophire-focus_full3314.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
