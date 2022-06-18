$Config = @{
    Identifier = 'Bilibili.Livehime'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://api.live.bilibili.com/client/v1/LiveHime/download?type=3'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object1.data.version, '([\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.dl_url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.data.ver_desc | Format-Text

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

    $ReleaseNotes = $Object2.data.list | Where-Object -FilterScript { $_.title.Contains($Result.Version) }
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
