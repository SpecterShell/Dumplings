$Config = @{
    Identifier = 'Versa.MagiCut'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://vmk.api.versa-ai.com/montage/pc/skip/latestVersion'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.result

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
