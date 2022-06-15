$Config = @{
    Identifier = 'Wondershare.PDFelement.CN'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 5387 -Version '8.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://cc-download.wondershare.cc/cbs_down/pdfelement_$($Result.Version)_full5387.exe"
        "https://cc-download.wondershare.cc/cbs_down/pdfelement_64bit_$($Result.Version)_full5387.exe"
    )

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://pdf.wondershare.cn/pdfelement/whats-new.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
