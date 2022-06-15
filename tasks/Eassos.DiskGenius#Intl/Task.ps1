$Config = @{
    Identifier = 'Eassos.DiskGenius'
    Skip       = $false
    Notes      = '国际版'
}

$Ping = {
    $Uri = 'https://internal.eassos.com/update/diskgenius/update.php'
    $Object = Invoke-RestMethod -Uri $Uri | ConvertFrom-Ini

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version.new

    # InstallerUrl
    $Result.InstallerUrl = "https://engdownload.eassos.cn/DGEngSetup$($Result.Version.Replace('.','')).exe"

    # ReleaseNotes
    $Result.ReleaseNotes = $Object[$Object.version.new].releasenote.Split('`|') | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.diskgenius.com/version-history.php'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.diskgenius.com/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[1]').InnerText.Trim().Contains($Result.Version) -and $Object2.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[3]').InnerText.Trim() -cmatch 'Updated: (.+)') {
        # ReleaseTime
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
