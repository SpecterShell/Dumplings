$Config = @{
    Identifier = 'Wondershare.PDFelement.6'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareXmlUpgradeApi -ProductId 2989 -Version '6.0.0.0'

    # InstallerUrl
    $Result.InstallerUrl = 'https://download.wondershare.com/cbs_down/pdfelement6_full2989.exe'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://pdf.wondershare.com/whats-new.html'

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
