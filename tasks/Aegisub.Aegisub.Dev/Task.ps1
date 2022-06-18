$Config = @{
    Identifier = 'Aegisub.Aegisub.Dev'
    Skip       = $false
}

$Ping = {
    $Uri = 'http://plorkyeran.com/aegisub/'
    $Prefix = 'http://plorkyeran.com/aegisub/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    $ReleaseNotesTitle = $Object.SelectSingleNode('/html/body/h3[1]').InnerText

    # Version
    $Result.Version = [regex]::Match($ReleaseNotesTitle, '(r[\d]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = @(
        ($Prefix + $Object.SelectSingleNode('/html/body/div[1]/a[1]').Attributes['href'].Value),
        ($Prefix + $Object.SelectSingleNode('/html/body/div[2]/a[1]').Attributes['href'].Value)
    )

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($ReleaseNotesTitle, '(\d{2}/\d{2}/\d{2})').Groups[1].Value,
        'MM/dd/yy',
        $null
    ).ToString('yyyy-MM-dd')

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('/html/body/ul[2]/li/text()').InnerText | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
