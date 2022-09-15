$Config = @{
    Identifier = 'Wondershare.DemoCreator'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['7743']

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/democreator_$($Result.Version)_full7743.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://democreator.wondershare.com/whats-new.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
