$Config = @{
    Identifier = 'Lenovo.LeAppStore'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pc-store.lenovomm.cn/upgrade/indep/upgrade_check'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.data.versionName

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri $Object.data.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.data.note | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
