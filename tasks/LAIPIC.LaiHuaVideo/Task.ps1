$Config = @{
    Identifier = 'LAIPIC.LaiHuaVideo'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://video.laihua.com/common/config?type=15'
    $Object = (Invoke-RestMethod -Uri $Uri).data.videoUpdate | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.versionCode

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.description | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.laihua.com/about?id=113'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.laihua.com/webapi/introduction/113'
    $Object2 = (Invoke-RestMethod -Uri $Uri2).data.content | ConvertFrom-Html

    if ($Object2.SelectSingleNode('/p[1]/span/span[1]/strong').InnerText.Trim().Contains($Result.Version)) {
        # ReleaseTime
        if ([System.Web.HttpUtility]::HtmlDecode($Object2.SelectSingleNode('/p[1]/span/span[2]').InnerText).Trim() -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
