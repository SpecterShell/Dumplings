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
    if ($Object.versions.Windows.version_number -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.versions.Windows.download_link

    # ReleaseTime
    $Result.ReleaseTime = ConvertFrom-UnixTimeSeconds -Seconds $Object.versions.Windows.release_time

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
