$Config = @{
    Identifier = 'Wondershare.PDFPasswordRemover'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 526 -Version '1.1.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/pdf-password-remover_full526.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
