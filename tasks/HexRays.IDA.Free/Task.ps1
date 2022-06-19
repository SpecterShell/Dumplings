$Config = @{
    Identifier = 'HexRays.IDA.Free'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://hex-rays.com/ida-free/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="download"]/div/div/div[1]/p[1]').InnerText,
        'v([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="download"]/div/div/div[2]/div[1]/p/a').Attributes['href'].Value

    # Hash
    $Result.Hash = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="download"]/div/div/div[1]/pre').InnerText,
        '([0-9a-f]+).+windows'
    ).Groups[1].Value

    return $Result
}

$ComparedProperties = @('Version', 'InstallerUrl', 'Hash')

return @{
    Config             = $Config
    Ping               = $Ping
    ComparedProperties = $ComparedProperties
}
