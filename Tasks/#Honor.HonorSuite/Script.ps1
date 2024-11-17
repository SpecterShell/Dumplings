$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['HonorSuite'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['HonorSuite'] = $OldReleases = [ordered]@{}
}

# International
# $Object1 = Invoke-RestMethod -Uri 'https://update.platform.hihonorcloud.com/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @"
# <?xml version="1.0" encoding="utf-8"?>
# <root>
#   <rule name="DashBoard">$($this.LastState.Version ?? '11.0.0.702')</rule>
#   <rule name="Region">Default</rule>
# </root>
# "@
# $Prefix1 = $Object1.root.components.component[-1].url + 'full/'
# $Object2 = Invoke-WebRequest -Uri "${Prefix1}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml
# $Object3 = Invoke-WebRequest -Uri "${Prefix1}$($Object2.root.files.file[0].spath)" | Read-ResponseContent | ConvertFrom-Xml

# $Version1 = [regex]::Match(
#   $Object1.root.components.component[-1].version,
#   '([\d\.]+)'
# ).Groups[1].Value

# China
$Object4 = Invoke-RestMethod -Uri 'https://update.platform.hihonorcloud.com/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @"
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">$($this.LastState.Version ?? '11.0.0.702')</rule>
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

# if ($Version1 -ne $Version2) {
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Version2

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = $Prefix1 + $Object2.root.files.file[1].spath
# }
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Prefix2 + $Object5.root.files.file[1].spath
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.root.components.component[-1].createtime | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesEN = $Object6.root.language.Where({ $_.code -eq '1033' }, 'First')[0].features.feature | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN = $Object6.root.language.Where({ $_.code -eq '2052' }, 'First')[0].features.feature | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotesEN = $ReleaseNotesEN
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
