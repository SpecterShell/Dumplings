$Config = @{
    Identifier = 'Tencent.TencentMeeting'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://meeting.tencent.com/web-service/query-download-info?q=[{%22package-type%22:%22app%22,%22channel%22:%220300000000%22,%22platform%22:%22windows%22}]&nonce=AAAAAAAAAAAAAAAA'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.'info-list'[0].version

    # InstallerUrl
    $Result.InstallerUrl = $Object.'info-list'[0].url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.'info-list'[0].'sub-date' -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
