$Config = @{
    Identifier = 'iSlide.iSlide'
    Skip       = $false
}

$Ping = {
    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = Get-RedirectedUrl -Uri 'https://api.islide.cc/download/package/exe'

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($Result.InstallerUrl, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
