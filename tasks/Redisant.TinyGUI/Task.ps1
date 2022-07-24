$Config = @{
    Identifier = 'Redisant.TinyGUI'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="Family"]/div/div[6]/div[3]/a/span').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="Family"]/div/div[6]/div[3]/a').Attributes['href'].Value

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
