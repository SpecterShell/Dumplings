$Config = @{
    Identifier = 'Woyun.wolai'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://cdn.wostatic.cn/dist/installers/electron-versions.json'
    $Prefix = 'https://cdn.wostatic.cn/dist/installers/'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.win.version

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.win.files[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.win.releaseDate.ToUniversalTime()

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
