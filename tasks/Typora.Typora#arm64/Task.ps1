$Config = @{
    Identifier = 'Typora.Typora'
    Skip       = $false
    Notes      = 'arm64'
}

$Ping = {
    $Uri1 = 'https://typora.io/releases/windows_arm.json'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Object1.download,
        $Object1.downloadCN
    )

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://typora.io/releases/stable'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    if ($Object2.SelectSingleNode('//*[@id="write"]/h2[1]').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="write"]/h2[contains(text(), "1.3.6")]/following-sibling::*[self::h4 or self::ul][count(.|//*[@id="write"]/h2[contains(text(), "1.3.6")]/following-sibling::h2[1]/preceding-sibling::*[self::h4 or self::ul])=count(//*[@id="write"]/h2[contains(text(), "1.3.6")]/following-sibling::h2[1]/preceding-sibling::*[self::h4 or self::ul])]/descendant-or-self::*[self::h4 or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } |
            Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
