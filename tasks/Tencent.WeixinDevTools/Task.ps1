$Config = @{
    Identifier = 'Tencent.WeixinDevTools'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://servicewechat.com/wxa-dev-logic/checkupdate?force=1'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Json

    $Result = [ordered]@{}
    
    # Version
    $Version = $Object.update_version.ToString()
    $Result.Version = $Version.SubString(0, 1) + '.' + $Version.SubString(1, 2) + '.' + $Version.SubString(3)
    
    # InstallerUrl
    $Result.InstallerUrl = @(
        Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=ia32&download_version=$($Object.update_version)&version_type=1&pack_type=0"
        Get-RedirectedUrl -Uri "https://servicewechat.com/wxa-dev-logic/download_redirect?os=win&type=x64&download_version=$($Object.update_version)&version_type=1&pack_type=0"
    )

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object.changelog_desc | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://developers.weixin.qq.com/miniprogram/en/dev/devtools/stable.html'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = $Object.changelog_url

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
