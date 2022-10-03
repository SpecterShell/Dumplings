$Config = @{
    Identifier = 'AcFun.AcFunVirtualTool'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.releaseInfo.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.releaseInfo.downloadUrl

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.releaseInfo.message | Format-Text

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://ytech-ai.kuaishou.cn/ytech/api/register'
    $Headers2 = @{
        Referer = 'https://livetool.kuaishou.com'
    }
    $Content2 = Invoke-RestMethod -Uri $Uri2 -Headers $Headers2 -SkipHeaderValidation

    $Key = $Content2.Split(':')[0]

    $Uri3 = "https://ytech-ai.kuaishou.cn/ytech/api/virtual/reconstruct/record?api_key=${Key}&timestamp=$([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())"
    $Object3 = Invoke-RestMethod -Uri $Uri3 -Headers $Headers2 -SkipHeaderValidation

    $ReleaseNotesUrl = $Object3.data.data.Where({ $_.iconText.Contains($Result.Version) })[0].link
    if ($ReleaseNotesUrl) {
        # ReleaseNotesUrl
        $Result.ReleaseNotesUrl = $ReleaseNotesUrl
    } else {
        # ReleaseNotesUrl
        $Result.ReleaseNotesUrl = $null
    }
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
