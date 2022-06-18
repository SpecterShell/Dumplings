$Config = @{
    Identifier = 'Tencent.QiDian'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://qidian.qq.com/store/qd_interface/Download.php'
    $Object = (Invoke-RestMethod -Uri $Uri).data | Where-Object -Property 'FPlatform' -EQ -Value '1'

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.FUrl

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, 'QiDian([\d\.]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.FReleaseTime | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://admin.qidian.qq.com/hp/helpCenter/list?cid=413'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
