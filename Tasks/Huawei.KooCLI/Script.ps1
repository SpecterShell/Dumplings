$Content = Invoke-RestMethod -Uri 'https://cn-north-4-hdn-koocli.obs.cn-north-4.myhuaweicloud.com/cli/latest/version.txt'

# Version
$Task.CurrentState.Version = $Version = $Content.Trim()

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = "https://cn-north-4-hdn-koocli.obs.cn-north-4.myhuaweicloud.com/cli/${Version}/huaweicloud-cli-windows-amd64.zip"
  NestedInstallerFiles = @(
    @{
      RelativeFilePath     = 'hcloud.exe'
      PortableCommandAlias = 'hcloud'
    }
  )
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
