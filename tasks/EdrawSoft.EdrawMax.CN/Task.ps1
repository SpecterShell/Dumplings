$Config = @{
    Identifier = 'EdrawSoft.EdrawMax.CN'
    Skip       = $false
}

$Ping = {
    $Result = $script:WondershareUpgradeInfo['5374']

    # InstallerUrl
    $Result.InstallerUrl = "https://cc-download.edrawsoft.cn/cbs_down/edraw-max_cn_$($Result.version)_full5374.exe"

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.edrawmax.cn/helpcenter/pc/releases'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://pixsoapi.edrawsoft.cn/api/helpcenter/draw/tutorial/list?class_id=6&product=2&platform=2'
    $Object2 = (Invoke-RestMethod -Uri $Uri2).data[0].content | ConvertFrom-Html

    if ($Object2.SelectSingleNode("/h1[contains(text(), `"$($Result.Version)`")]").InnerText.Contains($Result.Version)) {
        # ReleaseTime
        $Result.ReleaseTime = $Object2.SelectSingleNode("/h1[contains(text(), `"$($Result.Version)`")]/following-sibling::p[1]/span").InnerText | Get-Date -Format 'yyyy-MM-dd'
    }
    else {
        # ReleaseTime
        $Result.ReleaseTime = $null
    }

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
