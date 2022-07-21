$Config = @{
    Identifier = 'NetEase.IdentityV.CN'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://adl.netease.com/d/g/id5/c/gw?type=pc'
    $Content = (Invoke-WebRequest -Uri $Uri).Content

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = [regex]::Match($Content, "pc_link\s*=\s*`"(.+?)`"").Groups[1].Value

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl, '(\d+)\.exe').Groups[1].Value

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-FileVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
