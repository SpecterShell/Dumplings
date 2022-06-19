$Config = @{
    Identifier = 'FengHe.FocusNote'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://fn.kirakuapp.com/admin/version/listNew'
    $Form = @{
        platform = '0'
        prodNo   = '0'
    }
    $Object = Invoke-RestMethod -Uri $Uri -Method Post -Form $Form

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = [uri]::UnescapeDataString($Object.data[0].downloadUrl)

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.-]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.data[0].createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = @()
    $ReleaseNotes = $Object.data[0].updateLog | ConvertFrom-Json
    if ($ReleaseNotes.added) {
        $Result.ReleaseNotes += $ReleaseNotes.added -creplace '^', '[+ADDED] '
    }
    if ($ReleaseNotes.changed) {
        $Result.ReleaseNotes += $ReleaseNotes.changed -creplace '^', '[*CHANGED] '
    }
    if ($ReleaseNotes.fixed) {
        $Result.ReleaseNotes += $ReleaseNotes.fixed -creplace '^', '[-FIXED] '
    }
    $Result.ReleaseNotes = $Result.ReleaseNotes -join "`n"

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
