$Config = @{
    Identifier = 'Bosyun.BoardMix'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://boardmix-public.oss-accelerate.aliyuncs.com/cms/download/package/latest.yml'
    $Prefix = 'https://boardmix-public.oss-accelerate.aliyuncs.com/cms/download/package/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
