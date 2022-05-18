$Config = @{
    'Identifier' = 'Baidu.BaiduNetdisk'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'
    $Uri2 = 'https://pan.baidu.com/disk/version'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri1

    # Version
    if ($Object.list[0].version -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object.list[0].url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object.list[0].publish -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.list[0].detail.more | ConvertTo-OrderedList | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
