$Config = @{
    'Identifier' = 'Tencent.START'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://api.start.qq.com/cfg/get?biztypes=windows-update-info-start'
    $Object = (Invoke-RestMethod -Uri $Uri).configs.'windows-update-info-start'.value | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.latestversion

    # InstallerUrl
    $Result.InstallerUrl = $Object.downloadurl

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.updatedate -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.whatsnew | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
