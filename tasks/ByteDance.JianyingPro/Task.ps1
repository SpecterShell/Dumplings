$Config = @{
    Identifier = 'ByteDance.JianyingPro'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_80/bee_prod_80_bee_publish_3563.json'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.windows_download_pkg.channel_default

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'Jianying_pro_([\d_]+)_jianyingpro_0\.exe').Groups[1].Value.Replace('_', '.')

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($Object.windows_version_and_update_date, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
