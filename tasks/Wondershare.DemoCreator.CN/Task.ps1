$Config = @{
    Identifier = 'Wondershare.DemoCreator.CN'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['13164']

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/democreator_$($Result.Version)_full13164.exe"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
