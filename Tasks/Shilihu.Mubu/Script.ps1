$Object1 = Invoke-RestMethod -Uri 'https://api2.mubu.com/v3/api/desktop_client/latest_version'

# Version
$this.CurrentState.Version = $Object1.data.windows

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://assets.mubu.com/client/$($this.CurrentState.Version)/win/Mubu-$($this.CurrentState.Version)-ia32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://assets.mubu.com/client/$($this.CurrentState.Version)/win/Mubu-$($this.CurrentState.Version)-x64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('Mubu') -and $Global:DumplingsStorage.Mubu.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.Mubu[$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
