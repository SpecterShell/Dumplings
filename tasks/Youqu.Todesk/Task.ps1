$Config = @{
    Identifier = 'Youqu.Todesk'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.todesk.com/js/common.js'
    $Content1 = Invoke-WebRequest -Uri $Uri1 | Read-ResponseContent | ConvertTo-Lf

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Content1, "WIN_VERSION\s*=\s*'([\d\.]+)'").Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = [regex]::Match($Content1, "WIN_DOWNLOAD_URL\s*=\s*'(.+?)'").Groups[1].Value

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://update.todesk.com/windows/uplog.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/div/div/div[1]/div[1]/div[1]/div[1]').InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('/html/div/div/div[1]/div[1]/div[2]').InnerText,
            '(\d{4}\.\d{1,2}\.\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('/html/div/div/div[1]/div[2]/text()').InnerText | Format-Text
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
