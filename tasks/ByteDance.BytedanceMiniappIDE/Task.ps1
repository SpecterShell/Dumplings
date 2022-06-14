$Config = @{
    Identifier = 'ByteDance.BytedanceMiniappIDE'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6898629266087352589&branch=master&buildId=&uid='
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.manifest.win32.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.manifest.win32.urls[0]

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://microapp.bytedance.com/docs/zh-CN/mini-app/develop/developer-instrument/download/developer-instrument-update-and-download/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@class="markdown-render-content"]/div/h1[2]/text()').Text.Trim()
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        if ($ReleaseNotesTitle -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@class="markdown-render-content"]/div/h1[2]/following-sibling::ul[1]/li').InnerText | Format-Text | ConvertTo-UnorderedList
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
