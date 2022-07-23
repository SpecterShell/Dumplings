$Config = @{
    Identifier = 'Wondershare.PDFReader.CN'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['13143']

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://cc-download.wondershare.cc/cbs_down/pdfreader_$($Result.Version)_full13143.exe",
        "https://cc-download.wondershare.cc/cbs_down/pdfreader_64bit_$($Result.Version)_full13143.exe"
    )

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
