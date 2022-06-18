$Config = @{
    Identifier = 'Wondershare.Repairit.CN'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 11009 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://cc-download.wondershare.cc/cbs_down/repairit_full11009.exe'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
