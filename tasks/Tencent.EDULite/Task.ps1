$Config = @{
    Identifier = 'Tencent.EDULite'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://sas.qq.com/cgi-bin/ke_download_speed'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.win.download_url

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'EduLiteInstall_([\d\.]+)_.+\.exe').Groups[1].Value

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
