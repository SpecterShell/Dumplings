# International
$Object1 = Invoke-RestMethod -Uri 'https://update.platform.hihonorcloud.com/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @"
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">$($Task.LastState.Version ?? '11.0.0.702')</rule>
  <rule name="Region">Default</rule>
</root>
"@
$Prefix1 = $Object1.root.components.component[-1].url + 'full/'
$Object2 = Invoke-WebRequest -Uri "${Prefix1}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml
$Object3 = Invoke-WebRequest -Uri "${Prefix1}$($Object2.root.files.file[0].spath)" | Read-ResponseContent | ConvertFrom-Xml

$Version1 = [regex]::Match(
  $Object1.root.components.component[-1].version,
  '([\d\.]+)'
).Groups[1].Value

# Chinese
$Object4 = Invoke-RestMethod -Uri 'https://update.platform.hihonorcloud.com/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @"
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">$($Task.LastState.Version ?? '11.0.0.702')</rule>
  <rule name="Region">China</rule>
</root>
"@
$Prefix2 = $Object4.root.components.component[-1].url + 'full/'
$Object5 = Invoke-WebRequest -Uri "${Prefix2}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml
$Object6 = Invoke-WebRequest -Uri "${Prefix2}$($Object5.root.files.file[0].spath)" | Read-ResponseContent | ConvertFrom-Xml

$Version2 = [regex]::Match(
  $Object4.root.components.component[-1].version,
  '([\d\.]+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the locales"
  $Task.Config.Notes += '各个版本的版本号不相同'
}

# Version
$Task.CurrentState.Version = $Version2

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix1 + $Object2.root.files.file[1].spath
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Prefix2 + $Object5.root.files.file[1].spath
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object4.root.components.component[-1].createtime | Get-Date

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object3.root.language.Where({ $_.code -eq '1033' }).features.feature | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object6.root.language.Where({ $_.code -eq '2052' }).features.feature | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
