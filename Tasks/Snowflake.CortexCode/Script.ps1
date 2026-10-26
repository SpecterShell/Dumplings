$Object1 = Invoke-RestMethod -Uri 'https://sfc-repo.snowflakecomputing.com/coco-desktop/updates/prod/versions/latest.yml' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = 'https://sfc-repo.snowflakecomputing.com/coco-desktop/downloads/latest/Cortex-Code-win32-x64-user-setup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = 'https://sfc-repo.snowflakecomputing.com/coco-desktop/downloads/latest/Cortex-Code-win32-x64-system-setup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = 'https://sfc-repo.snowflakecomputing.com/coco-desktop/downloads/latest/Cortex-Code-win32-arm64-user-setup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = 'https://sfc-repo.snowflakecomputing.com/coco-desktop/downloads/latest/Cortex-Code-win32-arm64-system-setup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
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
