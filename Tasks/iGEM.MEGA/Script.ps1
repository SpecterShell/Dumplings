# x86
$Object1 = (Invoke-RestMethod -Uri 'https://www.megasoftware.net/current_release/').Where({ $_.app_name -eq 'MEGA X' -and $_.interface -eq 'Graphical (GUI)' -and $_.operating_system -eq 'windows' -and $_.cpu_arch -eq '32' -and $_.release_type -eq 'stable' }, 'First')[0]
$VersionX86 = "$($Object1.major).$($Object1.minor).$($Object1.release_number)"
# x64
$Object2 = (Invoke-RestMethod -Uri 'https://www.megasoftware.net/current_release/').Where({ $_.app_name -eq 'MEGA X' -and $_.interface -eq 'Graphical (GUI)' -and $_.operating_system -eq 'windows' -and $_.cpu_arch -eq '64' -and $_.release_type -eq 'stable' }, 'First')[0]
$VersionX64 = "$($Object2.major).$($Object2.minor).$($Object2.release_number)"

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  $this.Log('Inconsistent versions detected', 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://www.megasoftware.net/releases/MEGA_$($this.CurrentState.Version)_win32_setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.megasoftware.net/releases/MEGA_$($this.CurrentState.Version)_win64_setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://megasoftware.net/history' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='qi-question' and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="qi-answer"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
