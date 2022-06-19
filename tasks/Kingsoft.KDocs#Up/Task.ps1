$Config = @{
    Identifier = 'Kingsoft.KDocs'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Uri = 'https://www.kdocs.cn/kdg/api/v1/configure?idList=kdesktopWinVersion'
    # $Uri = 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopWinVersion'
    $Object = (Invoke-RestMethod -Uri $Uri).data.kdesktopWinVersion | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.changes | Format-Text

    return $Result
}

$ComparedProperties = @('Version')

return @{
    Config             = $Config
    Ping               = $Ping
    ComparedProperties = $ComparedProperties
}
