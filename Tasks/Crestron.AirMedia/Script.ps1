$Object1 = Invoke-WebRequest -Uri 'https://crestronairmedia.blob.core.windows.net/blob/packages/win/released/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = "https://www.crestron.com/software_files_public/am-100/airmedia_windows_$($this.CurrentState.Version)_deployable.exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://www.crestron.com/software_files_public/am-100/airmedia_windows_$($this.CurrentState.Version).msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = "https://www.crestron.com/software_files_public/am-100/airmedia_windows_$($this.CurrentState.Version)_unified.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.crestron.com/release_notes/airmedia_windows_installer_$($this.CurrentState.Version)_release_notes.pdf"
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
