$Object1 = (Invoke-RestMethod -Uri 'https://y.qq.com/download/download.js' | Get-EmbeddedJson -StartsFrom 'MusicJsonCallback(' | ConvertFrom-Json).data.Where({ $_.ID -eq 16 }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Flink1
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

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
