$Config = @{
    Identifier = 'Cube.CubePlatform'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://infobox.cubejoy.com/data.ashx?JsonData=%7B%22Code%22:%2210030%22%7D'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.result.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://download.cubejoy.com/app/$($Result.Version)/CubeSetup_v$($Result.Version).exe",
        "https://download.cubejoy.com/app/$($Result.Version)/CubeSetup_HK_TC_v$($Result.Version).exe"
    )

    $ReleaseNotes = ($Object.result.whatisnew | ConvertTo-Lf).Split("`n")

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($ReleaseNotes[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    if ($ReleaseNotes) {
        $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] | Format-Text
    }

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
