# x86
$Object1 = Invoke-RestMethod -Uri 'https://kelibiao.com/downloadclient.php?type=Desktop&plat=win32'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://kelibiao.com/downloadclient.php?type=Desktop&plat=win64'

if ($Object1.data.version -ne $Object2.data.version) {
  $this.Log("x86 version: $($Object1.data.version)")
  $this.Log("x64 version: $($Object2.data.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.url
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
