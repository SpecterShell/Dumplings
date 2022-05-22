$Config = @{
    'Identifier' = '1MHz.Knotes'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://knotes2-release-cn.s3.amazonaws.com/win/latest.yml'
    $Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

    $Result = Invoke-RestMethod -Uri $Uri | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
