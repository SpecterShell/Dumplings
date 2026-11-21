$Object1 = Invoke-RestMethod -Uri 'https://update-server.micloud.xiaomi.net/api/v1/releases'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.winx64
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'XiaomiCloud-(\d+\.\d+\.\d+)').Groups[1].Value


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
