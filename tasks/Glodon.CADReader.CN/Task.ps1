$Config = @{
    'Identifier' = 'Glodon.CADReader.CN'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://cad.glodon.com/update/version/info/cadpc'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.body.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.body.url

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object1.body.pageUrl
    $Object2 = Invoke-WebRequest -Uri $Result.ReleaseNotesUrl | ConvertFrom-Html

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div/p[@style="margin-top: 30px;"]/following-sibling::p[count(.|/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)=count(/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)]').InnerText | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
