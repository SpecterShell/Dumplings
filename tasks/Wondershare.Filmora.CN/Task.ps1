$Config = @{
    Identifier = 'Wondershare.Filmora.CN'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['3223']

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/filmora_$($Result.Version)_full3223.exe"

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
