$Config = @{
    Identifier = 'TTKN.CAJViewer.Simple'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://cajviewer.cnki.net/download.html'
    $Object = (Invoke-WebRequest -Uri $Uri | ConvertFrom-Html).SelectNodes(
        '/html/body/div[2]/div/div/div[contains(div[1]/div[2]/text(), "CAJViewer 7.3") and contains(div[1]/div[2]/text(), "精简版")]'
    )

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('div[1]/div[2]').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('div[5]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('div[4]/div').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
