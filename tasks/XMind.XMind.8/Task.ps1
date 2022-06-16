$Config = @{
    Identifier = 'XMind.XMind.8'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://www.xmind.net/_api/checkVersion/0?distrib=cathy_win32'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.buildId, '([\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.download

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact([regex]::Match($Result.Version, '(\d{12})'), 'yyyyMMddHHmm', $null) | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.whatsNew.Split("`n`n")[1] | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
