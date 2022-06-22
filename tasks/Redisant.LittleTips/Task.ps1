$Config = @{
    Identifier = 'Redisant.LittleTips'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.redisant.com/ltip/activate/checkUpdate'
    # $Uri = 'https://www.redisant.cn/ltip/activate/checkUpdate'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadUrl.Split('|')[0, 2]

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.enDescribes | Format-Text | ConvertTo-UnorderedList

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object.describes | Format-Text | ConvertTo-UnorderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
