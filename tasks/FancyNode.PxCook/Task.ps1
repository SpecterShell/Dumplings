$Config = @{
    'Identifier' = 'FancyNode.PxCook'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'http://www.fancynode.com.cn:8080/FancyApplicationService/update/pxcook/update_cooperation.do'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = 'https://fancynode.com.cn/pxcook/version'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.config.version

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Object1.config.downloadWin32,
        $Object1.config.downloadWin64
    )

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object1.config.date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="version-list1"]/*[self::div[@class="item"] or self::ul]//*[self::p or self::li]') | ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
