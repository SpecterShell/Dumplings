$Config = @{
    Identifier = 'Wondershare.PDFConverter.Pro'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 839 -Version '2.6.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/pdf-converter-pro_full839.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
