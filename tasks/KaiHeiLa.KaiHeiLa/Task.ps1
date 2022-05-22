$Config = @{
    'Identifier' = 'KaiHeiLa.KaiHeiLa'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://www.kaiheila.cn/api/v2/updates/latest-version?platform=windows'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.number

    # InstallerUrl
    $Result.InstallerUrl = $Object.url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.created_at | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.direction | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://blog.kaiheila.cn/category/%e7%89%88%e6%9c%ac%e6%9b%b4%e6%96%b0blog/'

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
