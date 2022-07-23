$Config = @{
    Identifier = 'Wondershare.CreativeCenter'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['10819']

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/wondershareCC_$($Result.Version)_full10819.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
