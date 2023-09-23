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
