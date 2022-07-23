$Config = @{
    Identifier = 'Wondershare.PDFReader'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['13142']

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://download.wondershare.com/cbs_down/pdfreader_$($Result.Version)_full13142.exe"
        "https://download.wondershare.com/cbs_down/pdfreader_64bit_$($Result.Version)_full13142.exe"
    )

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
