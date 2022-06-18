$Config = @{
    Identifier = 'Baidu.SwanIDE'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://smartprogram.baidu.com/mappconsole/api/devToolDownloadInfo?system=windows&type=online'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.download_url

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://smartprogram.baidu.com/docs/develop/devtools/uplog_tool_normal/'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://smartprogram.baidu.com/forum/api/docs_detail?path=%2Fdevelop%2Fdevtools%2Fuplog_tool_normal'
    $Object2 = ((Invoke-RestMethod -Uri $Uri2).data.content.body | ConvertFrom-Markdown).Html | ConvertFrom-Html

    if ($Object2.SelectNodes('/table[1]/tbody/tr/td[1]').InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('/table[1]/tbody/tr/td[2]').InnerText,
            '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('/table[1]/tbody/tr/td[3]/node()').InnerText | Format-Text
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
