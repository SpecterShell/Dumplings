$Prefix = 'https://consumer.huawei.com'

$Object1 = Invoke-RestMethod -Uri "${Prefix}/content/dam/huawei-cbg-site/cn/mkt/mobileservices/browser/new-version/js/nav.js"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Prefix + [regex]::Match($Object1, 'btnDown0\.attr\("href", "(.+?)"\)').Groups[1].Value
}
$VersionX64 = [regex]::Match($InstallerUrlX64, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlArm64 = $Prefix + [regex]::Match($Object1, 'btnDown1\.attr\("href", "(.+?)"\)').Groups[1].Value
}
$VersionX86 = [regex]::Match($InstallerUrlArm64, 'HuaweiBrowser-([\d\.]+)').Groups[1].Value

$Identical = $true
if ($VersionX64 -ne $VersionX86) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
