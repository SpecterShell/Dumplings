$Config = @{
    Identifier = 'Wondershare.Recoverit.CN'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlDownloadApi -ProductId 4516 -Wae '3.0.3'

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/data-recovery-64bit_$($Result.Version)_full4516.exe"

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
