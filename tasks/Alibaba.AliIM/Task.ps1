$Config = @{
    'Identifier' = 'Alibaba.AliIM'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://yungw.taobao.com/gw/invoke/taobao.jindoucloud.version.check2?clientSysName=Windows+PC&clientName=WangWang&clientVersion=9.12.10C&timestamp=0'
    $Headers = @{
        Referer = 'http://www.taobao.com/'
    }
    $Object = Invoke-RestMethod -Uri $Uri -Headers $Headers

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = "https://download.alicdn.com/wangwang/AliIM_taobao_($($Result.Version)).exe"

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.feature | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
