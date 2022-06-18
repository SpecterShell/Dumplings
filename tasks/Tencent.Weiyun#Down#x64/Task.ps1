$Config = @{
    Identifier = 'Tencent.Weiyun'
    Skip       = $false
    Notes      = '下载源 64 位'
}

$Ping = {
    $Uri = 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.electron_win64.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.electron_win64.download_url

    # ReleaseTime
    $Result.ReleaseTime = $Object.electron_win64.date | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
