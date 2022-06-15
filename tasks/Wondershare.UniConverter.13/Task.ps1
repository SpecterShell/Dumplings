$Config = @{
    Identifier = 'Wondershare.UniConverter.13'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 9629 -Version '13.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/uniconverter13_$($Result.Version)_full9629.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://videoconverter.wondershare.com/what-is-new.html'

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
