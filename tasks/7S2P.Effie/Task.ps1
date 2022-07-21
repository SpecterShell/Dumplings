$Config = @{
    Identifier = '7S2P.Effie'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.effie.pro/downloadfile/win'

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Uri

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
