$Config = @{
    'Identifier' = 'Alibaba.Yuque'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://app.nlark.com/yuque-desktop/v2/latest-lark.json'

    $Result = [ordered]@{}
    $Object = Invoke-RestMethod -Uri $Uri | Select-Object -ExpandProperty 'stable' | Where-Object -Property 'platform' -EQ -Value 'win32'

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.exe_url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.change_logs | ConvertTo-UnorderedList | Format-Text

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
