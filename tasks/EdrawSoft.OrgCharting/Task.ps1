$Config = @{
    Identifier = 'EdrawSoft.OrgCharting'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 5373

    # Version
    $Result.Version = [regex]::Match($Result.Version, '(\d+\.\d+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.edrawsoft.com/cbs_down/orgchartcreator_full5373.exe'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
