$Object1 = Invoke-WebRequest -Uri 'https://dewesoft.com/download/other-software'

$MatchX64 = [regex]::Match($Object1.Content, 'DSCalibrator_(\d+)_x64_release_(\d+)_(\d+)\.exe')
if (-not $MatchX64.Success) { throw 'No DSCalibrator x64 installer found on the download page' }
$MatchX86 = [regex]::Match($Object1.Content, 'DSCalibrator_(\d+)_x86_release_(\d+)_(\d+)\.exe')
if (-not $MatchX86.Success) { throw 'No DSCalibrator x86 installer found on the download page' }

# Version
$this.CurrentState.Version = "$($MatchX64.Groups[2].Value).$($MatchX64.Groups[3].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://downloads.dewesoft.com/other-software/$($MatchX64.Value)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://downloads.dewesoft.com/other-software/$($MatchX86.Value)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Object1.Content -match '(\d{1,2}/\d{1,2}/\d{4})</td><td[^>]*><div[^>]*><a href="[^"]*DSCalibrator_') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'M/d/yyyy', [System.Globalization.CultureInfo]::InvariantCulture).ToString('yyyy-MM-dd')
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
