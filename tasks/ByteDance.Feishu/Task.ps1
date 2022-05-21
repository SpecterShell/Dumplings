$Config = @{
    'Identifier' = 'ByteDance.Feishu'
    'Skip'       = $false
    'Note'       = @'
https://www.feishu.cn/hc/en-US/articles/360043073734
https://www.feishu.cn/hc/zh-CN/articles/360043073734
'@
}

$Fetch = {
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

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
