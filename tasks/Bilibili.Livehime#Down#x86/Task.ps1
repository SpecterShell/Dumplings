$Config = @{
    Identifier = 'Bilibili.Livehime'
    Skip       = $false
    Notes      = '下载源 32 位'
}

$Ping = {
    $Uri1 = 'https://api.live.bilibili.com/xlive/app-blink/v1/liveVersionInfo/getHomePageLiveVersion?system_version=1'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.curr_version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.download_url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.data.instruction | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://live.bilibili.com/liveHime/'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://api.live.bilibili.com/client/v1/LiveHime/getVerList?type=3'
    $Object2 = Invoke-RestMethod -Uri $Uri2

    $ReleaseNotes = $Object2.data.list.Where({ $_.title.Contains($Result.Version) })
    if ($ReleaseNotes) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match($ReleaseNotes.title, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
