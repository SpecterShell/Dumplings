$Config = @{
    Identifier = 'Bilibili.Bilibili'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://api.bilibili.com/x/elec-frontend/update/latest.yml'
    $Prefix = 'https://api.bilibili.com/x/elec-frontend/update/'
    $Headers = @{
        appversion = '0'
    }
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri ($Prefix + $Object.files[0].url) -Headers $Headers

    # ReleaseTime
    $Result.ReleaseTime = $Object.releaseDate.ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.news | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
