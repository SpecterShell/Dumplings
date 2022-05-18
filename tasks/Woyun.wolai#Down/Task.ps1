$Config = @{
    'Identifier' = 'Woyun.wolai'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://cdn.wostatic.cn/dist/installers/electron-versions.json'
    $Prefix = 'https://cdn.wostatic.cn/dist/installers/'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri

    # Version
    $Result.Version = $Object.win.version

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + [System.Uri]::EscapeUriString($Object.win.files[0].url)

    # ReleaseTime
    $Result.ReleaseTime = $Object.win.releaseDate.ToUniversalTime()

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
