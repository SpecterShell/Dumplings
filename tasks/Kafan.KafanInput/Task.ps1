$Config = @{
    Identifier = 'Kafan.KafanInput'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://input.kfsafe.cn/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.SelectSingleNode('/html/body/div[1]/div/div/p[5]/text()[1]').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('/html/body/div[1]/div/div/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('/html/body/div[1]/div/div/p[5]/text()[2]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://input.kfsafe.cn/logs.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/body/div/div[2]/div/div[2]/h3/span[1]').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div/div[2]/div/div[2]/ul/li/text()').InnerText | Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
