$Config = @{
    Identifier = 'Wondershare.Filmora.Pro'
    Skip       = $true
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 4622 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = @(
        'https://download.wondershare.com/cbs_down/filmorapro_full4622.exe'
        'https://download.wondershare.com/cbs_down/filmora_64bit_full4622.exe'
    )

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl[0] | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
