$Object1 = Invoke-WebRequest -Uri 'https://www.sdcard.org/downloads/formatter/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'SD Memory Card Formatter\s+(\d+(?:\.\d+)+)\s+for Windows').Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.sdcard.org/downloads/formatter/sd-memory-card-formatter-for-windows-download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'exe'
  NestedInstallerFiles = @(
    [ordered]@{ RelativeFilePath = "SDCardFormatterv5_WinEN/SD Card Formatter $($this.CurrentState.Version) Setup EN.exe" }
  )
  InstallerUrl         = Join-Uri 'https://www.sdcard.org/downloads/formatter/sd-memory-card-formatter-for-windows-download/' $Object2.Links.Where({ try { $_.href -match 'SDCardFormatterv5.+\.zip' } catch {} }, 'First')[0].href
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
