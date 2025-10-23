# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://lmstudio.ai/download/latest/win32/x64'
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+(-\d+)?)').Groups[1].Value

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://lmstudio.ai/download/latest/win32/arm64'
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+(?:\.\d+)+(-\d+)?)').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64 version: ${VersionX64}, arm64 version: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+(-\d+)?)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      if ($Global:DumplingsStorage.Contains('LMStudio') -and $Global:DumplingsStorage.LMStudio.Contains($this.CurrentState.RealVersion)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.LMStudio[$this.CurrentState.RealVersion].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    $this.Submit()
  }
}
