$Config = @{
    'Identifier' = '115.115'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://appversion.115.com/1/web/1.0/api/chrome'
    $Result = [PSCustomObject]@{}
    $Object = Invoke-RestMethod -Uri $Uri
    # Version
    Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.data.win.version_code -InputObject $Result
    # InstallerUrls
    Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $Object.data.win.version_url -InputObject $Result
    # ReleaseTime
    Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $($Object.data.win.created_time | ConvertFrom-UnixTimeSeconds) -InputObject $Result
    return $Result
}

Export-ModuleMember -Variable Config, Fetch
