$Config = @{
    Identifier = 'Wondershare.UniConverter.CN'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 4981 -Version '11.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/video-converter-ultimate_$($Result.Version)_full4981.exe"

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
