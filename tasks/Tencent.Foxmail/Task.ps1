$Config = @{
    Identifier = 'Tencent.Foxmail'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://datacollect.foxmail.com.cn/cgi-bin/foxmailupdate?f=xml'
    $Body = @'
<?xml version="1.0" encoding="utf-8"?>
<CheckForUpdate>
    <ProductName>Foxmail</ProductName>
    <Version>0</Version>
    <BuildNumber>0</BuildNumber>
    <RequestType>1</RequestType>
</CheckForUpdate>
'@
    $Object = Invoke-WebRequest -Uri $Uri -Method Post -Body $Body | Get-ResponseContent | ConvertFrom-Xml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.UpdateNotify.NewVersion

    # InstallerUrl
    $Result.InstallerUrl = $Object.UpdateNotify.PackageURL

    # ReleaseNotes
    $Result.ReleaseNotes = $Object.UpdateNotify.Description.'#cdata-section'.Replace('\r\n', "`n").Replace('\n', "`n") | Format-Text

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://www.foxmail.com/'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
