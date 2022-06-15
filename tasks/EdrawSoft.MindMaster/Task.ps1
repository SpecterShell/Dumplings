$Config = @{
    Identifier = 'EdrawSoft.MindMaster'
    Skip       = $false
}

$Ping = {
    $Result = Invoke-WondershareJsonUpgradeApi -ProductId 5375 -Version '8.0.0' -X86

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.edrawsoft.cn/cbs_down/mindmaster_cn_$($Result.version)_full5375.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.edrawsoft.cn/download/mindmaster/versioninfo/'

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
