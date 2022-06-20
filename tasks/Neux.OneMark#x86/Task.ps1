$Config = @{
    Identifier = 'Neux.OneMark'
    Skip       = $false
    Notes      = '32 位'
}

$Ping = {
    $Uri1 = 'https://onemark.neuxlab.cn/updates/latest.xml'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.item.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.item.url

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object1.item.changelog

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = $Result.ReleaseNotesUrl
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="main"]/div/ul/li').InnerText | Format-Text | ConvertTo-UnorderedList

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromMsi
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
