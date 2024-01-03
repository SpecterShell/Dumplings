$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $LocalStorage['HiSuite'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $LocalStorage['HiSuite'] = $OldReleaseNotes = [ordered]@{}
}

# International
$Object1 = Invoke-RestMethod -Uri 'https://query.hicloud.com:443/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @'
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">11.0.0.000</rule>
  <rule name="Region">Default</rule>
</root>
'@
$Prefix1 = $Object1.root.components.component[-1].url + 'full/'
$Object2 = Invoke-WebRequest -Uri "${Prefix1}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml
$Object3 = Invoke-WebRequest -Uri "${Prefix1}$($Object2.root.files.file[0].spath)" | Read-ResponseContent | ConvertFrom-Xml

$Version1 = [regex]::Match(
  $Object1.root.components.component[-1].version,
  '([\d\.]+)'
).Groups[1].Value

# Chinese
$Object4 = Invoke-RestMethod -Uri 'https://query.hicloud.com:443/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @'
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">11.0.0.000</rule>
  <rule name="Region">China</rule>
</root>
'@
$Prefix2 = $Object4.root.components.component[-1].url + 'full/'
$Object5 = Invoke-WebRequest -Uri "${Prefix2}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml
$Object6 = Invoke-WebRequest -Uri "${Prefix2}$($Object5.root.files.file[0].spath)" | Read-ResponseContent | ConvertFrom-Xml

$Version2 = [regex]::Match(
  $Object4.root.components.component[-1].version,
  '([\d\.]+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix1 + $Object2.root.files.file[1].spath
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Prefix2 + $Object5.root.files.file[1].spath
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.root.components.component[-1].createtime | Get-Date

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesEN = $Object3.root.language.Where({ $_.code -eq '1033' })[0].features.feature | Format-Text
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesCN = $Object6.root.language.Where({ $_.code -eq '2052' })[0].features.feature | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $OldReleaseNotes[$this.CurrentState.Version] = @{
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if (-not $this.Preference.NoWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
