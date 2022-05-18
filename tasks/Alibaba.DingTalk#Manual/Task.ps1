$Config = @{
    'Identifier' = 'Alibaba.DingTalk'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://im.dingtalk.com/manifest/new/release_windows_vista_later_manual_lowpriority.json'

    $Result = [ordered]@{}
    $Object = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Json

    # Version
    $Result.Version = $Object.win.package.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.win.package.url

    # ReleaseTime
    if ($Object.win.install.description[0] -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.win.install.description[1..($Object.win.install.description.length - 1)] -join "`n" | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
