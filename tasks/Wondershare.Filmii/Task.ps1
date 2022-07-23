$Config = @{
    Identifier = 'Wondershare.Filmii'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['7771']

    # InstallerUrl
    $Result.InstallerUrl = "https://download.wondershare.com/cbs_down/filmii_64bit_$($Result.Version)_full7771.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://filmii.wondershare.com/what-is-new.html'

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
