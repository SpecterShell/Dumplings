$Config = @{
    Identifier = 'SmartOldFish.OCRTools'
    Skip       = $false
}

$Ping = {
    $Uri = 'http://ocr.oldfish.cn:6060/update/update.xml'
    $Object = Invoke-WebRequest -Uri $Uri | Read-ResponseContent | ConvertTo-Lf | ConvertFrom-Xml

    $Result = [ordered]@{}

    # Version
    $Result.Version = $Object.xml.strNowVersion

    # InstallerUrl
    $Result.InstallerUrl = $Object.xml.strFullURL

    # ReleaseTime
    $Result.ReleaseTime = $Object.xml.dtNowDate | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotes
    $ReleaseNotes = $Object.xml.strContext.Split("`n")
    $Result.ReleaseNotes = $ReleaseNotes[1..($ReleaseNotes.Count - 1)] | Format-Text

    return $Result
}

$Pong = {
    param (
        [parameter(Mandatory)]
        $Result
    )

    # RealVersion
    $Result.RealVersion = Get-TempFile -Uri $Result.InstallerUrl | Read-ProductVersionFromExe
}

return @{
    Config = $Config
    Ping   = $Ping
    Pong   = $Pong
}
