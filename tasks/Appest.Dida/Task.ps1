$Config = @{
    Identifier = 'Appest.Dida'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pull.dida365.com/windows/release_note.json'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        (Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win'),
        (Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win64')
    )

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact($Object.release_date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

    # ReleaseNotes
    $Result.ReleaseNotes = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'en').content | Format-Text

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'zh_cn').content | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.dida365.com/public/changelog/en.html'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://www.dida365.com/public/changelog/zh.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
