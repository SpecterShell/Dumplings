$Config = @{
    'Identifier' = 'Baidu.BaiduNetdisk'
    'Skip'       = $false
}

$Fetch = {
    $Uri1 = 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Uri2 = 'https://pan.baidu.com/disk/version'

    $Result = [ordered]@{}

    # Version
    if ($Object1.list[0].version -cmatch 'V([\d\.]+)') {
        $Result.Version = $Matches[1].Trim()
    }

    # InstallerUrl
    $Result.InstallerUrl = $Object1.list[0].url

    # ReleaseTime
    $Result.ReleaseTime = Get-Date -Date $Object1.list[0].publish -AsUTC

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.list[0].detail.more | Format-Text | ConvertTo-OrderedList

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
