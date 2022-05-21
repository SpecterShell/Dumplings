$Config = @{
    'Identifier' = 'Alibaba.Yuque'
    'Skip'       = $false
}

$Fetch = {
    $Uri = 'https://app.nlark.com/yuque-desktop/v2/latest-lark.json'
    $Object = (Invoke-RestMethod -Uri $Uri).stable | Where-Object -Property 'platform' -EQ -Value 'win32'

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.exe_url

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.change_logs | Format-Text | ConvertTo-UnorderedList

    return [PSCustomObject]$Result
}

return [PSCustomObject]@{
    Config = $Config
    Fetch  = $Fetch
}
