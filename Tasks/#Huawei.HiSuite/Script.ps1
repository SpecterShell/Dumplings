$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['HiSuite'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['HiSuite'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri 'https://query.hicloud.com:443/sp_dashboard_global/UrlCommand/CheckNewVersion.aspx' -Method Post -Body @"
<?xml version="1.0" encoding="utf-8"?>
<root>
  <rule name="DashBoard">$($this.LastState.Contains('Version') ? $this.LastState.Version : '11.0.0.000')</rule>
  <rule name="Region">Default</rule>
</root>
"@
$Prefix = $Object1.root.components.component[-1].url + 'full/'
$Object2 = Invoke-WebRequest -Uri "${Prefix}filelist.xml" | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.root.components.component[-1].version,
  '(\d+(?:\.\d+)+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.root.files.file[1].spath
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object1.root.components.component[-1].createtime | Get-Date -AsUTC

    $Object3 = Invoke-WebRequest -Uri "${Prefix}changelog.xml" | Read-ResponseContent | ConvertFrom-Xml
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object3.root.language.Where({ $_.code -eq '1033' }, 'First')[0].features.feature | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object3.root.language.Where({ $_.code -eq '2052' }, 'First')[0].features.feature | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotes   = $ReleaseNotes
      ReleaseNotesCN = $ReleaseNotesCN
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
