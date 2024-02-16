# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win64'
}

$VersionX86 = [regex]::Match($InstallerUrlX86, '_(\d{4})[_.]').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'
$VersionX64 = [regex]::Match($InstallerUrlX64, '_(\d{4})[_.]').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

$Identical = $true
if ($VersionX86 -ne $VersionX64) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version = $VersionX64

if ($LocalStorage.Contains('Dida') -and $LocalStorage.Dida.Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage.Dida.$Version.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.Dida.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.Dida.$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseTime and ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
