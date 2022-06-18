$Config = @{
    Identifier = 'Catsxp.Catsxp'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://www.catsxp.com/api/service/Update?cup2key=:'
    $Body1 = @'
<?xml version="1.0" encoding="UTF-8"?>
<request>
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="" ap="x86-release" />
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="" ap="x64-release" />
</request>
'@
    $Object1 = Invoke-RestMethod -Uri $Uri1 -Method Post -Body $Body1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.response.app[0].updatecheck.manifest.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'download.catsxp.com' -Raw -SimpleMatch | ConvertTo-Https

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.catsxp.com/history'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Uri3 = 'https://www.catsxp.com/zh-hans/history'
    $Object3 = Invoke-WebRequest -Uri $Uri3 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@id="accordion"]/div[1]/a/h4/text()[2]').InnerText -cmatch '([\d\.]+)' -and $Result.Version.Contains($Matches[1])) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match(
            $Object2.SelectSingleNode('//*[@id="accordion"]/div[1]/a/h4/i').InnerText,
            '(\d{4}-\d{1,2}-\d{1,2} \d{2}:\d{2}:\d{2})'
        ).Groups[1].Value | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="collapseA1"]/div/p').InnerText | Format-Text
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null

        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    if ($Object3.SelectSingleNode('//*[@id="accordion"]/div[1]/a/h4/text()[2]').InnerText -cmatch '([\d\.]+)' -and $Result.Version.Contains($Matches[1])) {
        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $Object3.SelectNodes('//*[@id="collapseA1"]/div/p').InnerText | Format-Text
    }
    else {
        # ReleaseNotesCN
        $Result.ReleaseNotesCN = $null
    }

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = $Uri3
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
