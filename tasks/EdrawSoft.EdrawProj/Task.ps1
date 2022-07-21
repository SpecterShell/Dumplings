$Config = @{
    Identifier = 'EdrawSoft.EdrawProj'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 5372

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.edrawsoft.com/cbs_down/edrawproject_full5372.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
