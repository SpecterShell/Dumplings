$Config = @{
    Identifier = 'Logtalk.Logtalk'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://logtalk.org/download.html'
    $Prefix = 'https://logtalk.org/'
    $Object = Invoke-WebRequest -Uri $Uri | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[1]').InnerText,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.SelectSingleNode('//h3[@id="windows"]/following-sibling::blockquote[1]/p/a[1]').Attributes['href'].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[3]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://github.com/LogtalkDotOrg/logtalk3/blob/master/RELEASE_NOTES.md'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
