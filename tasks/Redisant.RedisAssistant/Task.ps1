$Config = @{
    Identifier = 'Redisant.RedisAssistant'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/activate/checkUpdate'
    # $Uri = 'https://www.redisant.cn/activate/checkUpdate'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.enDescribes[0..($Object.enDescribes.Length - 2)] | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object.describes[0..($Object.describes.Length - 2)] | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.redisant.com/download'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://www.redisant.cn/download'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
