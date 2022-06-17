$Config = @{
    Identifier = 'Tencent.EDU'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://sas.qq.com/cgi-bin/ke_download_pcClient'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.download_url

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'EduInstall_([\d\.]+)_sign\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.result.publish_time -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.result.desc | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
