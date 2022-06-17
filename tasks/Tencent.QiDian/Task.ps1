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
    $Result.ReleaseTime = Get-Date -Date $Object.FReleaseTime -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
