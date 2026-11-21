$Object1 = Invoke-WebRequest -Uri 'https://www.zultys.com/zac-download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = [regex]::Match($Object1.Content, 'https://.+?ZAC_x86.+?\.exe').Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = [regex]::Match($Object1.Content, 'https://.+?ZAC_x64.+?\.exe').Value
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

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
