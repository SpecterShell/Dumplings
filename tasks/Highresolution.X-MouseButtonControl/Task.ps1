$Config = @{
    Identifier = 'Highresolution.X-MouseButtonControl'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://highrez.co.uk/downloads/xmbc_changelog.htm'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('/html/body/div[2]/b').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri 'https://www.highrez.co.uk/scripts/download.asp?package=XMouse'

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match(
            $Object.SelectSingleNode('/html/body/div[2]/text()').InnerText,
            '\((.+)\)'
        ).Groups[1].Value,
        # "[string[]]" is needed here to convert "array" object to string array
        [string[]]@(
            "d'st' MMMM yyyy",
            "d'nd' MMMM yyyy",
            "d'rd' MMMM yyyy",
            "d'th' MMMM yyyy"
        ),
        (Get-Culture -Name 'en-US'),
        [System.Globalization.DateTimeStyles]::None
    )

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.SelectNodes('/html/body/ul[1]/li').InnerText.Replace("`t", ' ') | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
