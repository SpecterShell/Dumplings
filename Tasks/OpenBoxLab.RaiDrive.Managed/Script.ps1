$Object1 = Invoke-RestMethod -Uri 'https://www.raidrive.com/update/check' -Method Post -Body (
  @{
    product   = 'RaiDrive.Managed'
    plan      = ''
    version   = $this.Status.Contains('New') ? '2023.9.209.1' : $this.LastState.Version
    createdAt = Get-Date -Format 'yyyy-MM-dd'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

# Version
$this.CurrentState.Version = $Object1.LatestVersion

# Installer
$this.CurrentState.Installer += $InstallerExeX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_x86.exe"
}
$this.CurrentState.Installer += $InstallerExeX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_x64.exe"
}
$this.CurrentState.Installer += $InstallerExeArm64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_arm64.exe"
}
$this.CurrentState.Installer += $InstallerMsiX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_x86.msi"
}
$this.CurrentState.Installer += $InstallerMsiX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_x64.msi"
}
$this.CurrentState.Installer += $InstallerMsiArm64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msi'
  InstallerUrl  = "https://app.raidrive.com/download/raidrive/release/RaiDrive_$($this.CurrentState.Version)_arm64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Error')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.raidrive.com/update/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//main/div[contains(@class, 'container')]/div[contains(@class, 'container')]/div[contains(., 'RaiDrive $($this.CurrentState.Version -replace '\.1$')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Attributes.Contains('class') -and $Node.Attributes['class'].Value -match 'h3|small'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
  }
  'Updated' {
    $this.Submit()
  }
}
