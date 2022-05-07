$Config = @{
    'Identifier' = 'AcFun.AcFunVirtualTool'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'
    $Result = [PSCustomObject]@{}
    $Object = Invoke-RestMethod -Uri $Uri
    # Version
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.releaseInfo.version -InputObject $Result
    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $Object.releaseInfo.downloadUrl -InputObject $Result
    # ReleaseNotes
    Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value $Object.releaseInfo.message -InputObject $Result
    return $Result
}

Export-ModuleMember -Variable Config, Fetch
