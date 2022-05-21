$Config = @{
    'Identifier' = 'Bilibili.Livehime'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://api.live.bilibili.com/client/v1/LiveHime/download?type=3'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = 'https://api.live.bilibili.com/client/v1/LiveHime/getVerList?type=3'
    $Object2 = Invoke-RestMethod -Uri $Uri2

    $Uri3 = 'https://live.bilibili.com/liveHime/'

    $Result = [ordered]@{}

    # Version
    if ($Object1.data.version -cmatch '([\d\.]+)') {
        $Result.Version = $Matches[1]
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.dl_url

    # ReleaseTime
    if ($Object2.data.list[0].title -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.data.ver_desc | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri3

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
