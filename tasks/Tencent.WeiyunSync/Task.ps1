$Config = @{
    Identifier = 'Tencent.WeiyunSync'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.windows_sync.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.windows_sync.download_url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.windows_sync.date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
