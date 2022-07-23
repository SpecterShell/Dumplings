$Config = @{
    Identifier = 'EdrawSoft.EdrawMax.CN'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['5374']

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.edrawsoft.cn/cbs_down/edraw-max_cn_$($Result.version)_full5374.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.edrawsoft.cn/download/edrawmax/versioninfo/'

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
