$Config = @{
    Identifier = 'EdrawSoft.EdrawMax'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['5371']

    # InstallerUrl
    $Result.InstallerUrl = "https://download.edrawsoft.com/cbs_down/edraw-max_$($Result.Version)_full5371.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.edrawsoft.com/whats-new/edrawmax.html'

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
