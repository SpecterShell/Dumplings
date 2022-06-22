$Config = @{
    Identifier = 'Redisant.DataAssistant'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/da/activate/checkUpdate'
    # $Uri = 'https://www.redisant.cn/da/activate/checkUpdate'
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

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
