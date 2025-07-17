$Object1 = $Global:DumplingsStorage.ZWSOFTApps.data.Where({ $_.title -eq '网络服务套件' }, 'First')[0]
# $Object2 = Invoke-WebRequest -Uri $Object1.download.Where({ $_.name.Contains('32位') }, 'First')[0].url
$Object3 = Invoke-WebRequest -Uri $Object1.download.Where({ $_.name.Contains('64位') }, 'First')[0].url

# Installer
# $this.CurrentState.Installer += $InstallerX86 = [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = Join-Uri 'https://upgrade-online.zwsoft.cn' ([regex]::Match($Object2.Content, 'https://download\.zwsoft\.cn/\d+/[a-zA-Z0-9]+([^"]+)').Groups[1].Value)
# }
# $VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '_(\d+(?:\.\d+)+)[_.]').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://upgrade-online.zwsoft.cn' ([regex]::Match($Object3.Content, 'https://download\.zwsoft\.cn/\d+/[a-zA-Z0-9]+([^"]+)').Groups[1].Value)
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '_(\d+(?:\.\d+)+)[_.]').Groups[1].Value

# if ($VersionX86 -ne $VersionX64) {
#   $this.Log("x86 version: ${VersionX86}")
#   $this.Log("x64 version: ${VersionX64}")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.updateDate | Get-Date -Format 'yyyy-MM-dd'
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
