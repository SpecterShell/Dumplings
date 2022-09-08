$Config = @{
    Identifier = 'Coldlake.StellarPlayer'
    Skip       = $false
    Notes      = @'
下载源
https://www.stellarplayer.com/blog/category/post/changelog
'@
}

$Ping = {
    $Uri1 = 'https://player-update.coldlake1.com/version/info'
    $Object1 = [regex]::Match((Invoke-RestMethod -Uri $Uri1), '[^\(]+\((.+)\)').Groups[1].Value | ConvertFrom-Json

    $Result = [ordered]@{}

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Object1.data.official.x86.full.url,
        $Object1.data.official.x64.full.url
    )

    # Version
    $Result.Version = [regex]::Match($Result.InstallerUrl[0], '(\d{14})').Groups[1].Value

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact($Result.Version, 'yyyyMMddHHmmss', $null) | ConvertTo-UtcDateTime -Id 'China Standard Time'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = "https://player-update.coldlake1.com/version/gray/$($Result.Version)_x64.ini"
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Read-ResponseContent | ConvertFrom-Ini

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.update.info | Format-Text

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl[0] | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
