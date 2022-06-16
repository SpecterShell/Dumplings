$Config = @{
    Identifier = 'Redisant.KafkaAssistant'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/ka/activate/checkUpdate'
    # $Uri = 'https://www.redisant.cn/ka/activate/checkUpdate'
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
    $Result.ReleaseNotesUrl = 'https://www.redisant.com/ka/download'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://www.redisant.cn/ka/download'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
