$Config = @{
    Identifier = 'Superstar.ChaoXingStudy'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://apps.chaoxing.com/apis/apk/apkInfos.jspx?apkid=com.chaoxing.pc'
    $Object = Invoke-RestMethod -Uri $Uri

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.msg.apkInfo.version

    # InstallerUrl
    $Result.InstallerUrl = $Object.msg.apkInfo.downloadurl

    # ReleaseNotes
    $ReleaseNotes = $Object.msg.apkInfo.message.Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Length - 1)] | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
