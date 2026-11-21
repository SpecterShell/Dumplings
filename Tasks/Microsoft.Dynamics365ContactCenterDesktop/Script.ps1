$Object1 = Get-TempFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2309700'
$Object2 = 7z.exe e -y -so $Object1 'cabJson.json' | ConvertFrom-Json
Remove-Item -Path $Object1 -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

# Version
$this.CurrentState.Version = $Object2.latestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.downloadUrl
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
