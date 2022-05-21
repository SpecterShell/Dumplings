$Config = @{
    'Identifier' = 'Baidu.BaiduNetdisk'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    if ($Object.list[0].version -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.list[0].url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.list[0].publish | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.list[0].detail.more | Format-Text | ConvertTo-OrderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://pan.baidu.com/disk/version'

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
