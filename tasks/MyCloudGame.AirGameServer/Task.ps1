$Config = @{
    Identifier = 'MyCloudGame.AirGameServer'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.mycloudgame.com/download.html'
    $Prefix = 'https://www.mycloudgame.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="SERVER_VER"]').InnerText,
        '\((.+)\)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = @(
        ($Prefix + $Object.SelectSingleNode('//*[@id="SERVER_LINK"]').Attributes['href'].Value),
        $Object.SelectSingleNode('//*[@id="SERVER_LINK2"]').Attributes['href'].Value
    )

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
