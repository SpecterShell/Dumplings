$Config = @{
    Skip = $false
}

$Ping = {
    $script:WondershareUpgradeInfo = @{}

    $Products = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Assets_Products.yaml') | ConvertFrom-Yaml
    @('x64', 'x86').ForEach(
        {
            $Arch = $_
            $Request = @{
                Uri    = 'https://pc-api.300624.com/v2/product/batch-check-upgrade'
                Method = 'Post'
                Body   = @{
                    platform = "win_${Arch}"
                    versions = $Products.Where({ $_.x86 -eq ($Arch -eq 'x86') }).ForEach({ @{pid = $_.ProductId.ToString(); version = $_.Version } })
                } | ConvertTo-Json -Compress
            }
            Invoke-RestMethod @Request
        }
    ).data.ForEach(
        {
            $script:WondershareUpgradeInfo[$_.pid.ToString()] = [ordered]@{
                # Version
                Version      = $_.version
                # ReleaseNotes
                ReleaseNotes = $_.whats_new_content | Format-Text
            }
        }
    )

    return [ordered]@{}
}


return @{
    Config = $Config
    Ping   = $Ping
}
