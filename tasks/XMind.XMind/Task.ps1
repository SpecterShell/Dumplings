$Config = @{
    Identifier = 'XMind.XMind'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.xmind.app/xmind/update/latest-win64.yml'
    $Object = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.'releaseNotes-en-US' | Format-Text

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object.'releaseNotes-zh-CN' | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.xmind.net/desktop/release-notes'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://www.xmind.cn/desktop/release-notes/'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
