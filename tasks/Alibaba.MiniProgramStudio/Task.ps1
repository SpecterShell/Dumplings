$Config = @{
    'Identifier' = 'Alibaba.MiniProgramStudio'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://hpmweb.alipay.com/tinyApp/queryAppUpdate/latest.yml?productId=TINY_APP_IDE_WINDOWS&productVersion=1.0.0&osType=ANDROID&forceCheckByUser=true'
    $Object = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.path.Trim()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.guideMemo | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://opendocs.alipay.com/mini/ide/stable_log'

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
