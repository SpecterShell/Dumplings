$Config = @{
    Identifier = 'Skillbrains.Lightshot'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://updater.prntscr.com/getver/lightshot'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.update.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.update.installerurl | ConvertTo-Https

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
