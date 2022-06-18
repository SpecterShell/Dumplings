$Config = @{
    Identifier = '360.360Chrome'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://browser.360.cn/ee/'
    $Object1 = Invoke-WebRequest -Uri $Uri1 | ConvertFrom-Html

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object1.SelectSingleNode('//*[@id="loadnew"]').Attributes['href'].Value

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://bbs.360.cn/thread-15913525-1-1.html'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $ReleaseNotesTitle = $Object2.SelectSingleNode('//*[@id="postmessage_117915619"]/strong[1]').InnerText
    if ($ReleaseNotesTitle.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}年\d{1,2}月\d{1,2}日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="postmessage_117915619"]/strong[1]/following-sibling::text()[count(.|//*[@id="postmessage_117915619"]/strong[2]/preceding-sibling::text())=count(//*[@id="postmessage_117915619"]/strong[2]/preceding-sibling::text())]').InnerText | Format-Text
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
