$Config = @{
    Identifier = 'Bosyun.BoardMix'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://boardmix-public.oss-accelerate.aliyuncs.com/cms/download/package/latest.yml'
    $Prefix = 'https://boardmix-public.oss-accelerate.aliyuncs.com/cms/download/package/'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertFrom-Yaml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Prefix + $Object.files[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.releaseDate.ToUniversalTime()

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.releaseNotes | Format-Text | ConvertTo-OrderedList

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
