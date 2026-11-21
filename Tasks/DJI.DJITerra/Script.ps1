$Object1 = Invoke-RestMethod -Uri 'https://terra-1-g.djicdn.com/851d20f7b9f64838a34cd02351370894/DJI%20Terra/new_version.txt' | ConvertFrom-Csv -Delimiter ' ' -Header @('Version', 'ReleaseDate', 'InstallerUrl') | Select-Object -Last 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.InstallerUrl | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
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
