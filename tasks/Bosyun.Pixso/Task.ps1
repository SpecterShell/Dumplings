$Config = @{
    Identifier = 'Bosyun.Pixso'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://pixso-public.oss-accelerate.aliyuncs.com/cms/download/package/latest.yml'
    $Prefix = 'https://pixso-public.oss-accelerate.aliyuncs.com/cms/download/package/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
