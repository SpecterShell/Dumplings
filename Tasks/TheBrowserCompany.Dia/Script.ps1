# Not released yet, but the URL scheme should be similar. Remind me when it's released ;)

# x64
$Object1 = Invoke-RestMethod -Uri 'https://releases.diabrowser.com/windows/prod/Dia.appinstaller' -MaximumRetryCount 0
# # arm64
# $Object2 = Invoke-RestMethod -Uri 'https://releases.diabrowser.com/windows/prod/Dia.arm64.appinstaller'

# if ($Object1.AppInstaller.Version -ne $Object2.AppInstaller.Version) {
#   $this.Log("x64 version: $($Object1.AppInstaller.Version)")
#   $this.Log("arm64 version: $($Object2.AppInstaller.Version)")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.AppInstaller.MainPackage.Uri
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Object2.AppInstaller.MainPackage.Uri
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  # 'Changed|Updated' {
  #   $this.Message()
  # }
  'Updated' {
    $this.Submit()
  }
}
