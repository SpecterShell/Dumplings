$Config = @{
    Identifier = 'Kingsoft.KDocs'
    Skip       = $false
    Notes      = '下载源'
}

$Ping = {
    $Uri = 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopVersion,autoDownload'
    # $Uri = 'https://www.kdocs.cn/kdg/api/v1/configure?idList=kdesktopVersion,autoDownload'
    $Object1 = (Invoke-RestMethod -Uri $Uri).data.kdesktopVersion | ConvertFrom-Json
    $Object2 = (Invoke-RestMethod -Uri $Uri).data.autoDownload | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object1.win, 'v([\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object2.kdesktopWin.1001

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
