$Config = @{
    Identifier = 'Youku.YoukuClient'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pcapp-update.youku.com/check?action=web_iku_install_page&cid=iku'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.method.ikuver

    # InstallerUrl
    $Result.InstallerUrl = $Object.method.iku_package

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($Object.method.iku_desc, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
