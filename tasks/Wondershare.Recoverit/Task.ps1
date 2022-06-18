$Config = @{
    Identifier = 'Wondershare.Recoverit'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 4134 -Wae '3.0.3'

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/recoverit_64bit_$($Result.Version)_full4134.exe"

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
