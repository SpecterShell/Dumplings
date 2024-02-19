# International x64
$Object1 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater.json').maxthon.Where({ $_.channels -contains 'stable' }, 'First')[0]
# International x86
$Object2 = (Invoke-RestMethod -Uri 'https://updater.maxthon.com/mx6/com/updater_x86.json').maxthon.Where({ $_.channels -contains 'stable' }, 'First')[0]
# Chinese x64
$Object3 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater.json').maxthon.Where({ $_.channels -contains 'stable' }, 'First')[0]
# Chinese x86
$Object4 = (Invoke-RestMethod -Uri 'https://updater.maxthon.cn/mx6/cn/updater_x86.json').maxthon.Where({ $_.channels -contains 'stable' }, 'First')[0]

$Identical = $true
if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property 'version' -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object4.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
