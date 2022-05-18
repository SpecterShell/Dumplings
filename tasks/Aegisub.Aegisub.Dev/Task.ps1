$Config = @{
    'Identifier' = 'Aegisub.Aegisub.Dev'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'http://plorkyeran.com/aegisub/'
    $Prefix = 'http://plorkyeran.com/aegisub/'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri | ConvertFrom-Html

    # Version
    if ($Object.SelectSingleNode('/html/body/h3[1]').InnerText -cmatch '(r[\d]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = @(
        ($Prefix + $Object.SelectSingleNode('/html/body/div[1]/a[1]').Attributes['href'].Value),
        ($Prefix + $Object.SelectSingleNode('/html/body/div[2]/a[1]').Attributes['href'].Value)
    )

    # ReleaseTime
    if ($Object.SelectSingleNode('/html/body/h3[1]').InnerText -cmatch '(\d{2}/\d{2}/\d{2})') {
        $Result.ReleaseTime = [datetime]::ParseExact($Matches[1], 'MM/dd/yy', $null).ToString('yyyy-MM-dd')
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('/html/body/ul[2]/li/text()').Text | ConvertTo-OrderedList | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
