# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl -Uri 'https://www.ticktick.com/static/getApp/download?type=win'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'https://www.ticktick.com/static/getApp/download?type=win64'
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

if ($Global:DumplingsStorage.Contains('TickTick') -and $Global:DumplingsStorage.TickTick.Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.TickTick.$Version.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.TickTick.$Version.ReleaseNotesEN
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage.TickTick.$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseTime and ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
