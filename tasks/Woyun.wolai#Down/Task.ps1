$Config = @{
    'Identifier' = 'Woyun.wolai'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://cdn.wostatic.cn/dist/installers/electron-versions.json'
    $Prefix = 'https://cdn.wostatic.cn/dist/installers/'

    $Result = [PSCustomObject]@{}
    $Object = Invoke-RestMethod @WebRequestParameters -Uri $Uri

    # Version
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.win.version -InputObject $Result

    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value "$($Prefix)$([System.Uri]::EscapeDataString($Object.win.files[0].url))" -InputObject $Result

    # ReleaseTime
    Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $Object.win.releaseDate.ToUniversalTime() -InputObject $Result

    return $Result
}

return [PSCustomObject]@{Config = $Config; Fetch = $Fetch }
