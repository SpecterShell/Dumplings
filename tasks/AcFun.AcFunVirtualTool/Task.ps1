$Config = @{
    'Identifier' = 'AcFun.AcFunVirtualTool'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'

    $Result = @{}
    $Object = Invoke-RestMethod -Uri $Uri

    # Version
    $Result.Version = $Object.releaseInfo.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.releaseInfo.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.releaseInfo.message | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
