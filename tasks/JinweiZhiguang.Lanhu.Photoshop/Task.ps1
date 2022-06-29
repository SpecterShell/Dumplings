$Config = @{
    Identifier = 'JinweiZhiguang.Lanhu.Photoshop'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://lanhuapp.com/api/project/app_version?apptype=lanhu_ps_windows'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = $Object.result.url

    # Version
    $Result.Version = [regex]::Match($Object.result.url, 'Lanhu-([\d\.]+)-windows-installer\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = $Object.result.create_time | Get-Date

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
