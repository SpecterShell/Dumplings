$Object1 = (Invoke-WebRequest -Uri 'https://tandemhealth.blob.core.windows.net/tandem-public/native/releases.win.json' | Read-ResponseContent | ConvertFrom-Json).Assets | Where-Object -FilterScript { $_.Type -eq 'Full' } | Sort-Object -Property { [ChunkVersion]($_.Version) } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# RealVerison
$this.CurrentState.RealVersion = $Object1.Version.Split('-')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://tandemhealth.blob.core.windows.net/tandem-public/native/Tandem-win-Setup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
