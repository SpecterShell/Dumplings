$Config = @{
    Identifier = 'Hitencent.JisuPDF'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://jisupdf.com/zh-cn/pdf-reader.html'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[1]').InnerText.Trim() -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/div[1]').Attributes['href'].Value

    # ReleaseTime
    if ($Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[3]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

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

    # ReleaseNotes
    $ReleaseNotes = $Object2.data.list | Where-Object -Property 'version' -CMatch -Value ([regex]::Escape($Result.Version))
    if ($ReleaseNotes) {
        $Result.ReleaseNotes = $ReleaseNotes.content | Format-Text
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
