# x86
$Object1 = Invoke-RestMethod -Uri 'https://aec.pcw365.com/forceupdatenew.php?type=draw&bit=0'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://aec.pcw365.com/forceupdatenew.php?type=draw&bit=1'

# Version
$this.CurrentState.Version = $Object2.root.curversionnow_name

if ($Object1.root.curversionnow_name -ne $Object2.root.curversionnow_name) {
  $this.Log("x86 version: $($Object1.root.curversionnow_name)")
  $this.Log("x64 version: $($Object2.root.curversionnow_name)")
  throw 'Inconsistent versions detected'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.root.updateExeUrl | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.root.updateExeUrl | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.root.description.'#text' | Format-Text
      }
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
