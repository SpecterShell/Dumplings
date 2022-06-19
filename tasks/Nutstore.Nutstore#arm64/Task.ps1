$Config = @{
    Identifier = 'Nutstore.Nutstore'
    Skip       = $false
    Notes      = 'arm64'
}

$Ping = {
    $Uri1 = 'https://www.jianguoyun.com/static/exe/latestVersion'
    $Object1 = (Invoke-RestMethod -Uri $Uri1) | Where-Object -Property 'OS' -EQ -Value 'win-wpf-client-arm64'

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.exVer

    # InstallerUrl
    $Result.InstallerUrl = @(
        "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($Result.Version)/NutstoreWindowsWPF_Full_$($Result.Version)_ARM64.exe"
    )

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://help.jianguoyun.com/?p=1415'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="post-1415"]/div/p[1]/strong').InnerText.Trim()
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        if ($ReleaseNotesTitle -cmatch '(\d{4}年\d{1,2}月\d{1,2}日)') {
            $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
        }

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="post-1415"]/div/ol[1]/li').InnerText | Format-Text | ConvertTo-OrderedList
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
