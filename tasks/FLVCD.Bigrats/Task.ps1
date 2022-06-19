$Config = @{
    Identifier = 'FLVCD.Bigrats'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://download.flvcd.com/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/div/a/span/text()').InnerText,
        'v([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/div/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[2]/td[1]/p[1]/text()[1]').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    $ReleaseNotes = $Object.SelectSingleNode('/html/body/table/tr[4]/td/table/tr[3]/td/pre').InnerText -csplit '硕鼠更新日志.+' |
        Where-Object -FilterScript { $_.Contains($Result.Version) } |
        Format-Text
    if ($ReleaseNotes) {
        # ReleaseNotes
        $ReleaseNotes = $ReleaseNotes.Split("`n")
        $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] -join "`n"
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
