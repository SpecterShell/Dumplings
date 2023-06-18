$Content = (Invoke-WebRequest -Uri 'https://msedgedriver.azureedge.net/LATEST_STABLE' | Read-ResponseContent).Trim()

# Version
$Task.CurrentState.Version = $Version = $Content

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_win32.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_win64.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerUrl         = "https://msedgedriver.azureedge.net/${Version}/edgedriver_arm64.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'msedgedriver.exe'
      PortableCommandAlias = 'msedgedriver'
    }
  )
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
