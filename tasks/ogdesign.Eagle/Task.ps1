$Config = @{
    Identifier = 'ogdesign.Eagle'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://eagle.cool/check-for-update'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.links.windows, 'Eagle-([\d\.]+-build\d+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = @(
        ('https:' + $Object.links.windows.Replace('eaglefile.oss-cn-shenzhen.aliyuncs.com', 'r2-app.eagle.cool').Replace('file.eagle.cool', 'r2-app.eagle.cool')),
        ('https:' + $Object.links.windows)
    )

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://eagle.cool/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('//*[@id="hero"]/div/div/div/div/div[3]/text()[2]').InnerText,
        '(\d{4}/\d{1,2}/\d{1,2})'
    ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://en.eagle.cool/changelog'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://cn.eagle.cool/changelog'

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl[0] | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
