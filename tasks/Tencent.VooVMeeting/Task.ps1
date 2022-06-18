$Config = @{
    Identifier = 'Tencent.VooVMeeting'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://voovmeeting.com/wemeet-webapi/v2/config/query-download-info'
    $Body = @{
        instance = 'windows'
        type     = '1410000197'
    } | ConvertTo-Json -Compress -AsArray
    $Object = Invoke-RestMethod -Uri $Uri -Method Post -Body $Body

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data[0].version

    # InstallerUrl
    $Result.InstallerUrl = $Object.data[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.data[0].sub_date | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
