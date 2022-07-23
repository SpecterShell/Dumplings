$Config = @{
    Identifier = 'Wondershare.WXRecovery'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['7546']

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/wxrecovery_$($Result.Version)_full7546.exe"

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
