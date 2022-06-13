$Config = @{
    Identifier = 'Alibaba.DingTalk'
    Skip       = $false
    Notes      = @'
自动更新源
https://alidocs.dingtalk.com/i/p/Y7kmbokZp3pgGLq2/docs/gXMGnr6AkOP814d6rvOmJybeZRxlzopj
'@
}

$Ping = {
    $Uri = 'https://im.dingtalk.com/manifest/new/release_windows_vista_later_all.json'
    $Object = Invoke-WebRequest -Uri $Uri | Get-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.win.package.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.win.install.url

    # ReleaseTime
    if ($Object.win.install.description[0] -cmatch '(\d{4}-\d{1,2}-\d{1,2})') {
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.win.install.multi_lang_description.en_US[1..($Object.win.install.description.length - 1)] | Format-Text

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object.win.install.description[1..($Object.win.install.description.length - 1)] | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
