$Config = @{
    Identifier = 'Glodon.CADReader'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://cadreader.glodon.com/query/update/cadpc?clientVersion=3.4.3.12&cadpcClientBits=32'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.version

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.url

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Object1.data.pageUrl

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Object2 = Invoke-WebRequest -Uri $Result.ReleaseNotesUrl | ConvertFrom-Html

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('/html/body/div/p[2]/following-sibling::p[count(.|/html/body/div/br/preceding-sibling::p)=count(/html/body/div/br/preceding-sibling::p)]').InnerText | Format-Text
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
