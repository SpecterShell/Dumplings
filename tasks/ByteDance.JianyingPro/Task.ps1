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
    if ($Result.InstallerUrl -cmatch '_([0-9_]+)_') {
        $Result.Version = $Matches[1].Replace('_', '.')
    }

    # ReleaseTime
    if ($Object.windows_version_and_update_date -cmatch '(\d{4}/\d{1,2}/\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
