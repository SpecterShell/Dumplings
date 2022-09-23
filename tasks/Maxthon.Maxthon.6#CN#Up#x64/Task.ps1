$Config = @{
    Identifier = 'Maxthon.Maxthon.6'
    Skip       = $false
    Notes      = '国内版 升级源 64 位'
}

$Ping = {
    $Uri = 'https://updater.maxthon.cn/mx6/cn/updater.json'
    $Object = (Invoke-RestMethod -Uri $Uri).maxthon | Where-Object -Property 'channels' -Contains -Value 'stable'

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.url

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.maxthon.cn/mx6/changelog/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@id="app"]/div[1]/h2[1]/text()').InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('//*[@id="app"]/div[1]/h2[1]/time').InnerText,
            '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="app"]/div[1]/p[1]/span').InnerText | Format-Text
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

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
