$Config = @{
    'Identifier' = 'Youku.YoukuClient'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://pcapp-update.youku.com/check?action=web_iku_install_page&cid=iku'

    $Result = [PSCustomObject]@{}
    $Object = Invoke-RestMethod @WebRequestParameters -Uri $Uri

    # Version
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.method.ikuver -InputObject $Result

    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $Object.method.iku_package -InputObject $Result

    # ReleaseTime
    if ($Object.method.iku_desc -cmatch '日期 ([\d/]+)') {
        $ReleaseTime = Get-Date -Date $Matches[1].Trim() -Format 'yyyy-MM-dd'
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $ReleaseTime -InputObject $Result
    }

    return $Result
}

return [PSCustomObject]@{Config = $Config; Fetch = $Fetch }
