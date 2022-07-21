$Config = @{
    Identifier = 'HexRays.IDA.Free'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.hex-rays.com/cgi-bin/oracle.cgi?prod0=IDAFRENW&ver0=0.0.0&prod1=IDAFRECW&ver1=0.0.0&prod2=IDAFREFW&ver2=0.0.0&vercheck=1'
    $Object1 = Invoke-RestMethod -Uri $Uri1 | ConvertFrom-Ini

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.IDAFRE.ver

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://hex-rays.com/ida-free/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    # InstallerUrl
    $Result.InstallerUrl = $Object2.SelectSingleNode('//*[@id="download"]/div/div/div[2]/div[1]/p/a').Attributes['href'].Value
}

$ComparedProperties = @('Version')

return @{
    Config             = $Config
    Ping               = $Ping
    Pong               = $Pong
    ComparedProperties = $ComparedProperties
}
