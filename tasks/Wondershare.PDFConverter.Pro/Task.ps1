$Config = @{
    Identifier = 'Wondershare.PDFConverter.Pro'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 839

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/pdf-converter-pro_full839.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
