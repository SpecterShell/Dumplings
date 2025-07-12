# Version
$this.CurrentState.Version = [regex]::Match(
  (curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.blender.org/download/' | Join-String -Separator "`n"),
  'blender-([\w\.]+)-windows'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.blender.org/release/Blender$($this.CurrentState.Version.Split('.')[0..1] -join '.')/blender-$($this.CurrentState.Version)-windows-x64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.blender.org/download/releases/$($this.CurrentState.Version.Split('.')[0..1] -join '-')/"
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
