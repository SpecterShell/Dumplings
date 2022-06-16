$Config = @{
    Identifier = 'Tencent.QQMusic'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://u.y.qq.com/cgi-bin/musicu.fcg'
    $Body1 = @{
        comm                                              = @{
            ct       = '19'
            cv       = '0'
            tmeAppID = 'qqmusic'
        }
        'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate' = @{
            method = 'QueryUpdate'
            module = 'platform.uniteUpdate.UniteUpdateSvr'
            param  = @{}
        }
    } | ConvertTo-Json -Compress
    $Object1 = Invoke-WebRequest -Uri $Uri1 -Method Post -Body $Body1 | Get-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgVersion.ToString().Insert(2, '.')

    # InstallerUrl
    $Result.InstallerUrl = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgDesc | Format-Text | ConvertTo-UnorderedList

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://y.qq.com/download/download.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/h3/span').InnerText.Trim().Contains($Result.Version)) {
        # ReleaseTime
        if ($Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/ul/li[last()]').InnerText.Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
