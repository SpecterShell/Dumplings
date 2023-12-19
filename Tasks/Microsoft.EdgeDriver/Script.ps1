$Content = (Invoke-WebRequest -Uri 'https://msedgedriver.azureedge.net/LATEST_STABLE' | Read-ResponseContent).Trim()

# Version
$this.CurrentState.Version = $Version = $Content

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_win32.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_win64.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_arm64.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
