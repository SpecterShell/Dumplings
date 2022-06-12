$Config = @{
    Identifier = 'Aegisub.Aegisub.Dev'
    Skip       = $false
}

$Ping = {
    $Uri = 'http://plorkyeran.com/aegisub/'
    $Prefix = 'http://plorkyeran.com/aegisub/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    if ($Object.SelectSingleNode('/html/body/h3[1]').InnerText.Trim() -cmatch '(r[\d]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = @(
        ($Prefix + $Object.SelectSingleNode('/html/body/div[1]/a[1]').Attributes['href'].Value),
        ($Prefix + $Object.SelectSingleNode('/html/body/div[2]/a[1]').Attributes['href'].Value)
    )

    # ReleaseTime
    if ($Object.SelectSingleNode('/html/body/h3[1]').InnerText.Trim() -cmatch '(\d{2}/\d{2}/\d{2})') {
        $Result.ReleaseTime = [datetime]::Parse($Matches[1], [cultureinfo]::GetCultureInfo('en-US')).ToString('yyyy-MM-dd')
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('/html/body/ul[2]/li/text()').Text | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
