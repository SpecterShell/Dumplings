$Config = @{
    Identifier = 'Hitencent.JisuTodo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc.jisutodo.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/ul/li[1]').InnerText.Trim() -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/a').Attributes['href'].Value

    # ReleaseTime
    if ($Object.SelectSingleNode('//*[@id="banner"]/div/div[1]/ul/li[2]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    return $Result
}

$ComparedProperties = @('Version')

return @{
    Config             = $Config
    Ping               = $Ping
    ComparedProperties = $ComparedProperties
}
