$Config = @{
    Identifier = 'Wondershare.Repairit'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 5913

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/repairit_$($Result.Version)_full5913.exe"

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
