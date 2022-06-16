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

    if ($Object2.SelectSingleNode('//*[@id="hero"]/div/div/div/div/div[3]/text()[2]').Text.Trim() -cmatch '(\d{4}/\d{1,2}/\d{1,2})') {
        # ReleaseTime
        $Result.ReleaseTime = Get-Date -Date $Matches[1] -Format 'yyyy-MM-dd'
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://trello.com/b/LSsVep1d/eagle-development-roadmap'

    # ReleaseNotesUrlCN
    $Result.ReleaseNotesUrlCN = 'https://trello.com/b/YgBOPQ6x/eagle-%E4%BA%A7%E5%93%81%E8%B7%AF%E7%BA%BF%E5%9B%BE'

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl[0] | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
