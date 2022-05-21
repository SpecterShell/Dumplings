$Config = @{
    'Identifier' = 'Alibaba.AlipayDevelopmentAssistant'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://ideservice.alipay.com/ide/api/pluginVersion.json?platform=win&clientType=assistant'
    $Headers = @{
        Referer = 'https://openhome.alipay.com'
    }
    $Object = Invoke-RestMethod -Uri $Uri -Headers $Headers

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.baseResponse.data.versionName

    # InstallerUrl
    $Result.InstallerUrl = $Object.baseResponse.data.downloadUrl

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
