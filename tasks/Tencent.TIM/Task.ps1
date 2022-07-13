$Config = @{
    Identifier = 'Tencent.TIM'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://im.qq.com/rainbow/TIMDownload/'
    $Object = Invoke-RestMethod -Uri $Uri | Read-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.app.download.pcLink

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.app.download.pcDatetime | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://tim.qq.com/support.html'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
