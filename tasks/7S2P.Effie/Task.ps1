$Config = @{
    Identifier = '7S2P.Effie'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.effie.co/downloadfile/win'

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Uri

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1]
    }

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
