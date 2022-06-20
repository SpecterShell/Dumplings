$Config = @{
    Identifier = 'TTKN.CNKIExpress'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://download.cnki.net/cnkiexpress/latest.yml'
    $Prefix = 'https://download.cnki.net/cnkiexpress/'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.files[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.releaseDate.ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = ($Object.releaseNotes -csplit '(?m)^\s*[\d\.]+\s*$')[1] | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
