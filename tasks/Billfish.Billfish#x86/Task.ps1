$Config = @{
    Identifier = 'Billfish.Billfish'
    Skip       = $false
    Notes      = '32 位'
}

$Ping = {
    $Uri1 = 'https://front-gw.aunapi.com/applicationService/installer/getAppVersion?appId=10301011&versionCode=0.0.0.0&packageSystemSupport=1'
    $Object1 = Invoke-RestMethod -Uri $Uri1

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object1.data.versionCode

    # InstallerUrl
    $Result.InstallerUrl = $Object1.data.downloadUrl

    # ReleaseTime
    $Result.ReleaseTime = $Object1.data.createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    $Uri2 = 'https://www.billfish.cn/download/'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    if ($Object2.SelectSingleNode('//*[@id="download-page"]/div[2]/table/tr[2]/td[2]').InnerText.Contains($Result.Version)) {
        # ReleaseNotes
        $Result.ReleaseNotes = $Object2.SelectNodes('//*[@id="download-page"]/div[2]/table/tr[2]/td[3]').InnerText | Format-Text
    }
    else {
        # ReleaseNotes
        $Result.ReleaseNotes = $null
    }

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = $Uri2
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
