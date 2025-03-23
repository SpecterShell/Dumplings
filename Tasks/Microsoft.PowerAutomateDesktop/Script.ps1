$Object1 = Get-TempFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2166902'
# $Object1 = Get-TempFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2200869'
$Object2 = 7z.exe e -y -so $Object1 'PADUpdate.json' | ConvertFrom-Json
Remove-Item -Path $Object1 -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

# Version
$this.CurrentState.Version = $Object2.latestVersion.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2102613'
  # InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2164365'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.latestVersion.releaseDate.ToUniversalTime()
    }
    catch {
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
