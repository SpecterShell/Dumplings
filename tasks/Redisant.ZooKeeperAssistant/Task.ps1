$Config = @{
    Identifier = 'Redisant.ZooKeeperAssistant'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/za/activate/checkUpdate'
    # $Uri = 'https://www.redisant.cn/za/activate/checkUpdate'
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
    $Result.ReleaseNotesUrl = 'https://www.redisant.com/za/download'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://www.redisant.cn/za/download'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
