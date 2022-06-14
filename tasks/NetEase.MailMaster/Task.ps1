$Config = @{
    Identifier = 'NetEase.MailMaster'
    Skip       = $false
}

$Ping = {
    $Uri = 'http://fm.dl.126.net/mailmaster/update2/update_config.json'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.full[0].ver

    # InstallerUrl
    $Result.InstallerUrl = $Object.full[0].url

    # ReleaseNotes
    $ReleaseNotes = $Object.full[0].introduction.Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 3)] | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
