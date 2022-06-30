$Config = @{
    Identifier = 'KOOK.KOOK'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.kookapp.cn/api/v2/updates/latest-version?platform=windows'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.number

    # InstallerUrl
    $Result.InstallerUrl = $Object.url

    # ReleaseTime
    $Result.ReleaseTime = $Object.created_at | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.direction | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
