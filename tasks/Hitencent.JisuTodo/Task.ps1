$Config = @{
    Identifier = 'Hitencent.JisuTodo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc.jisutodo.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/ul/li[1]').InnerText,
        'V([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/ul/li[2]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

$ComparedProperties = @('Version')

return @{
    Config             = $Config
    Ping               = $Ping
    ComparedProperties = $ComparedProperties
}
