$Config = @{
    Identifier = 'Hitencent.JisuPDF'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://jisupdf.com/zh-cn/pdf-reader.html'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[1]').InnerText,
        'V([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/div[1]').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[3]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://jisupdf.com/zh-cn/log.html'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://jisupdf.com/ApiProduct/log'
    $Object2 = Invoke-RestMethod -Uri $Uri2

    $ReleaseNotes = $Object2.data.list | Where-Object -FilterScript { $_.version.Contains($Result.Version) }
    if ($ReleaseNotes) {
        # ReleaseNotes
        $Result.ReleaseNotes = $ReleaseNotes.content | Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
