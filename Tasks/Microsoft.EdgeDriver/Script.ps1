$Object1 = (Invoke-WebRequest -Uri 'https://msedgedriver.azureedge.net/LATEST_STABLE' | Read-ResponseContent).Trim()

# Version
$this.CurrentState.Version = $Object1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = "https://msedgedriver.azureedge.net/$($this.CurrentState.Version)/edgedriver_win32.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/$($this.CurrentState.Version)/edgedriver_win64.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/$($this.CurrentState.Version)/edgedriver_arm64.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
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
