$Config = @{
    Identifier = 'Wondershare.MirrorGo'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 8050 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/mirror_go_$($Result.Version)_full8050.exe"

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
