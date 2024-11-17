$Prefix = 'https://download.qoppa.com/pdfstudio/v2024/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}updates.xml"
# x86
$Object2 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '12451' }, 'First')[0]
# x64
$Object3 = $Object1.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '13020' }, 'First')[0]

if ($Object2.newVersion -ne $Object3.newVersion) {
  $this.Log("x86 version: $($Object2.newVersion)")
  $this.Log("x64 version: $($Object3.newVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object3.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object2.fileName
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object3.fileName
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
