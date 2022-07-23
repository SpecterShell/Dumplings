$Config = @{
    Skip       = $false
}

$Ping = {
    $script:WondershareUpgradeInfo = @{}

    $Products = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Assets_Products.yaml') | ConvertFrom-Yaml
    (@('x64', 'x86') | ForEach-Object -Process {
        Invoke-RestMethod -Uri 'https://pc-api.300624.com/v2/product/batch-check-upgrade' -Method Post -Body (
            @{
                platform = "win_${_}"
                versions = $Products.Where({ $_.x86 -eq ($_ -eq 'x86') }).ForEach({ @{pid = $_.ProductId.ToString(); version = $_.Version } })
            } | ConvertTo-Json -Compress
        )
    }).data.ForEach(
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
