$Config = @{
    Identifier = 'Wondershare.UBackit'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 8767 -Version '1.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/ubackit_$($Result.Version)_full8767.exe"

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
