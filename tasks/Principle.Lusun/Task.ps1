$Config = @{
    Identifier = 'Principle.Lusun'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://releases.lusun.com/latest.yml'
    $Prefix = 'https://releases.lusun.com/'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Prefix + $Object.files.Where({ $_.url.Contains('ia32') })[0].url
        $Prefix + $Object.files.Where({ $_.url.Contains('x64') })[0].url
    )

    # ReleaseTime
    $Result.ReleaseTime = $Object.releaseDate.ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.releaseNotes | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://principle.feishu.cn/mindnotes/bmncnnwj8J8h6TEjM4hXWThODyb'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
