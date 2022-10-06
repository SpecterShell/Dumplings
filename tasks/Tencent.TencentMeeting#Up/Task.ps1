$Config = @{
    Identifier = 'Tencent.TencentMeeting'
    Skip       = $false
    Notes      = "升级源"
}

$Ping = {
    $Uri = 'https://meeting.tencent.com/web-service/query-app-update-info/?os=Windows&app_publish_channel=TencentInside&sdk_id=0300000000&from=2&appver=3.11.0.0'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.package_url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.features_description | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
