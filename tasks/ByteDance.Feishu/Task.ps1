$Config = @{
    Identifier = 'ByteDance.Feishu'
    Skip       = $false
    Notes      = @'
https://www.feishu.cn/hc/en-US/articles/360043073734
https://www.feishu.cn/hc/zh-CN/articles/360043073734
'@
}

$Ping = {
    $Uri = 'https://www.feishu.cn/api/downloads'
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
