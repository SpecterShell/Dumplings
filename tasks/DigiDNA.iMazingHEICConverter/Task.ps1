$Config = @{
    Identifier = 'DigiDNA.iMazingHEICConverter'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://downloads.imazing.com/com.DigiDNA.iMazingHEICConverterWindows.xml'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object[0].enclosure.version

    # InstallerUrl
    $Result.InstallerUrl = $Object[0].enclosure.url

    # ReleaseTime
    $Result.ReleaseTime = $Object[0].pubDate | Get-Date -AsUTC

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object[0].releaseNotesLink

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
