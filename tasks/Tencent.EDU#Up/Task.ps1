$Config = @{
    Identifier = 'Tencent.EDU'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://sas.qq.com/cgi-bin/pcedu_qtedu_appupgrade'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = 'https:' + $Object.result.student.check_upgrade.url

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'EduInstall_([\d\.]+)_sign\.exe').Groups[1].Value

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.result.student.check_upgrade.tips | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
