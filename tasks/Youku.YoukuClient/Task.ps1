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
    if ($Object.method.iku_desc -cmatch '日期 (\d{4}/\d{1,2}/\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
