$Config = @{
    'Identifier' = '115.115Chrome'
    'Skip'       = $false
}

$Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'

$Fetch = {
    $Result = [PSCustomObject]@{}
    $Object = Invoke-RestMethod -Uri $Uri

    # Version
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.data.window_115.version_code -InputObject $Result

    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $Object.data.window_115.version_url -InputObject $Result

    # ReleaseTime
    Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $($Object.data.window_115.created_time | ConvertFrom-UnixTimeSeconds) -InputObject $Result

    return $Result
}

Export-ModuleMember -Variable Config, Fetch
