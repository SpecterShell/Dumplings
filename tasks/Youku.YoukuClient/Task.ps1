$Config = @{
    'Identifier' = 'Youku.YoukuClient'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://pcapp-update.youku.com/check?action=web_iku_install_page&cid=iku'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri

    # Version
    $Result.Version = $Object.method.ikuver

    # InstallerUrl
    $Result.InstallerUrl = $Object.method.iku_package

    # ReleaseTime
    if ($Object.method.iku_desc -cmatch '日期 ([\d/]+)') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
    }

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
