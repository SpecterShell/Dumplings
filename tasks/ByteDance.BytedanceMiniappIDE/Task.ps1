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

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@class="markdown-render-content"]/div/h1[2]/text()').InnerText
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@class="markdown-render-content"]/div/h1[2]/following-sibling::ul[1]/li').InnerText | Format-Text | ConvertTo-UnorderedList
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
