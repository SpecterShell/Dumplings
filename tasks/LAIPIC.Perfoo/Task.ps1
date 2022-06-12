$Config = @{
    Identifier = 'LAIPIC.Perfoo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://presentment-api.laihua.com/common/config?type=120'
    $Object = (Invoke-RestMethod -Uri $Uri).data.perfooUpdatePC | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.versionCode

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.description -creplace '；', "；`n" | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
