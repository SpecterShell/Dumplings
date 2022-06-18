$Config = @{
    Identifier = 'PortSwigger.BurpSuite.Community'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://portswigger.net/Burp/Releases/CheckForUpdates?product=community&channel=Stable&version=0'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.updates[0].version

    # InstallerUrl
    $Result.InstallerUrl = "https://portswigger-cdn.net/burp/releases/download?product=community&version=$($Result.Version)&type=WindowsX64"
    # $Result.InstallerUrl = "https://portswigger-cdn.net/burp/releases/intooldownload?product=community&channel=Stable&version=$($Result.Version)&number=$($Object.updates[0].number)&installationType=win64"

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.updates[0].description | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object.updates[0].releaseNotesUrl

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Object2 = Invoke-WebRequest -Uri $Result.ReleaseNotesUrl | ConvertFrom-Html

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        $Object2.SelectSingleNode('/html/body/section[2]/div/div[1]/div/div[2]').InnerText.Trim(),
        "dd MMM yyyy 'at' HH:mm 'UTC'",
        (Get-Culture -Name 'en-US')
    ) | ConvertTo-UtcDateTime -Id 'UTC'
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
