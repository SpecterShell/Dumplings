$Object1 = Invoke-RestMethod -Uri 'https://sr-releases.thelevel.ai/versions/sorted'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.items[0].id, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://sr-releases.thelevel.ai/download/flavor/default/$($this.CurrentState.Version)/windows_64?filetype=.msi&installerType=systemWide"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.items[0].assets.Where({ $_.filetype -eq '.msi' -and $_.platform -eq 'windows_64' -and $_.name -match 'SystemWide' }, 'First')[0].updatedAt.ToUniversalTime()
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
