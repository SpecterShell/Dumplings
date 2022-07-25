$Config = @{
    Identifier = 'Tencent.TranSmart'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://transmart.qq.com/api/resourcemanageserver/findAllClientVersion'
    $Body = @{
        value = 'TranSmart'
    } | ConvertTo-Json -Compress
    $ContentType = 'application/json'
    $Object = Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType $ContentType

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Object.value.windows[0].version, '(Alpha[\d\.]+)').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = $Object.value.windows[0].url

    # ReleaseTime
    $Result.ReleaseTime = $Object.value.windows[0].publish_time | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.value.windows[0].describe_content | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
