$Config = @{
    'Identifier' = '7S2P.Effie'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://www.effie.co/downloadfile/win'

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Uri

    # Version
    if ($Result.InstallerUrl -cmatch '([\d\.]+)\.exe') {
        $Result.Version = $Matches[1].Trim()
    }

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
