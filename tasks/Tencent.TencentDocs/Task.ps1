$Config = @{
    Identifier = 'Tencent.TencentDocs'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://docs.qq.com/rainbow/config.v2.ConfigService/PullConfigReq'
    $Headers = @{
        'Content-Type' = 'application/json'
    }
    $Body = @{
        'pull_item'    = @{
            'app_id' = 'e4099bf9-f579-4233-9a15-6625a48bcb56';
            'group'  = 'Prod.Common.Update'
        }
        'client_infos' = @(
            @{
                'client_identified_name'  = 'uin'
                'client_identified_value' = '99'
            }
        )
    } | ConvertTo-Json -Compress
    $Object = (Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body).config.items[0].key_values[0].value | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.version

    # InstallerUrl
    $Result.InstallerUrl = @($Object.download_win, $Object.download_win_arm)

    $ReleaseNotes = $Object.update_info.Split("`n")

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($ReleaseNotes[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $ReleaseNotes[2..$ReleaseNotes.Length] | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://docs.qq.com/doc/DZGZITkNhUFlXZklL?pub=1&dver=2.1.0'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
