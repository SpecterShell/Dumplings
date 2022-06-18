$Config = @{
    Identifier = 'aloneguid.BrowserTamer'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.aloneguid.uk/projects/bt'
    $Prefix = 'https://www.aloneguid.uk/projects/bt/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[1]/strong').InnerText.Trim()

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[4]/a').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match(
            $Object.SelectSingleNode('//*[@id="page"]/main/div/table/tbody/tr[1]/td[2]').InnerText,
            '(\d{1,2}/\d{1,2}/\d{4})'
        ).Groups[1].Value,
        'dd/MM/yyyy',
        $null
    ).ToString('yyyy-MM-dd')

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('//*[@id="page"]/main/div/table/tbody/tr[1]/td[3]').InnerText | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.aloneguid.uk/projects/bt#version-history'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
