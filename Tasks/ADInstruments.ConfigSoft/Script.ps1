$Object1 = Use-EdgeDriver {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://www.adinstruments.com/support/downloads/windows/configsoft')
  $EdgeDriver.PageSource
} | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri $Object1.Where({ try { $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    $InstallerFileExtracted = Expand-TempArchive -Path $InstallerFile -RelativeFilePath 'ConfigSoft 64bit\setup.exe'
    try {
      # RealVersion
      $this.CurrentState.RealVersion = (Get-InstallShieldMsiInfo -Path (Join-Path $InstallerFileExtracted 'ConfigSoft 64bit\setup.exe') -Name 'ConfigSoft.msi').ProductVersion
    } finally {
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
