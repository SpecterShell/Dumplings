$Config = @{
    Identifier = 'Wondershare.Filmora'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 846 -Version '10.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/filmora_64bit_$($Result.Version)_full846.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://filmora.wondershare.com/whats-new-in-filmora-video-editor.html'

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
