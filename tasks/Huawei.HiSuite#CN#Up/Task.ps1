$Config = @{
    Identifier = 'Huawei.HiSuite'
    Skip       = $false
    Notes      = '国内版升级源（地址不使用）'
}

$Ping = {
    $Uri1 = 'https://query.hicloud.com:443/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx'
    $Body1 = @'
<?xml version="1.0" encoding="utf-8"?>
<root>
    <rule name="DashBoard">11.0.0.000</rule>
    <rule name="Region">China</rule>
</root>
'@
    $Object1 = Invoke-WebRequest -Uri $Uri1 -Method Post -Body $Body1 | ConvertFrom-Xml

    $Prefix = "$($Object1.root.components.component[-1].url)full/"

    $Uri2 = "${Prefix}filelist.xml"
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Read-ResponseContent | ConvertFrom-Xml

    $Uri3 = "${Prefix}$($Object2.root.files.file[0].spath)"
    $Object3 = Invoke-WebRequest -Uri $Uri3 | Read-ResponseContent | ConvertFrom-Xml

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match(
        $Object1.root.components.component[-1].version,
        '([\d\.]+)'
    ).Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = "${Prefix}$($Object2.root.files.file[1].spath)"

    # ReleaseTime
    $Result.ReleaseTime = $Object1.root.components.component[-1].createtime | Get-Date

    # ReleaseNotes
    $Result.ReleaseNotes = $Object3.root.language.Where({ $_.code -eq '1033' }).features.feature | Format-Text

    # ReleaseNotesCN
    $Result.ReleaseNotesCN = $Object3.root.language.Where({ $_.code -eq '2052' }).features.feature | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
