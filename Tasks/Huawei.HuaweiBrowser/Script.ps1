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

if ($VersionX64 -ne $VersionX86) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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
