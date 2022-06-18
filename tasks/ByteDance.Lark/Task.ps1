$Config = @{
    Identifier = 'ByteDance.Lark'
    Skip       = $false
    Notes      = @'
https://www.larksuite.com/hc/en-US/articles/360046836333
https://www.larksuite.com/hc/zh-CN/articles/360046836333
'@
}

$Ping = {
    $Uri = 'https://www.larksuite.com/api/downloads'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.versions.Windows.version_number, 'V([\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.versions.Windows.download_link

    # ReleaseTime
    $Result.ReleaseTime = $Object.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
