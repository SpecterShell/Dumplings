$Config = @{
    Identifier = 'Tencent.TencentDocs'
    Skip       = $false
}

$Ping = {
    $Uri1 = 'https://docs.qq.com/rainbow/config.v2.ConfigService/PullConfigReq'
    $Body1 = @{
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
    $ContentType1 = 'application/json'
    $Object1 = (Invoke-RestMethod -Uri $Uri1 -Method Post -Body $Body1 -ContentType $ContentType1).config.items.Where({ $_.group -eq 'Prod.Common.Update' }).key_values.Where({ $_.key -eq 'update_info' }).value | ConvertFrom-Json

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.version

    $ReleaseNotes = $Object1.update_info.Split("`n")

    # ReleaseTime
    $Result.ReleaseTime = [regex]::Match($ReleaseNotes[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $Result.ReleaseNotes = $ReleaseNotes[2..$ReleaseNotes.Length] | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://docs.qq.com/doc/p/1021a084756aecce345430ed666a5e84e78466f6?pub=1&dver=2.1.0'

    $Prefix = "https://dldir1.qq.com/weiyun/tencentdocs/electron-update/release/$($Result.Version)/"
    $Uri2 = "${Prefix}latest-win32-ia32.yml"
    $Object2 = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Yaml
    $Uri3 = "${Prefix}latest-win32-x64.yml"
    $Object3 = Invoke-RestMethod -Uri $Uri3 | ConvertFrom-Yaml
    $Uri4 = "${Prefix}latest-win32-arm64.yml"
    $Object4 = Invoke-RestMethod -Uri $Uri4 | ConvertFrom-Yaml

    # InstallerUrl
    $Result.InstallerUrl = @(
        $Prefix + $Object2.files[0].url
        $Prefix + $Object3.files[0].url
        $Prefix + $Object4.files[0].url
    )

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
