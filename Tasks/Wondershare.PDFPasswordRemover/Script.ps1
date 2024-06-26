$this.CurrentState = Invoke-WondershareXmlUpgradeApi -ProductId 526 -Version '1.1.0.0' -Locale 'en-US'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = 'https://download.wondershare.com/cbs_down/pdf-password-remover_full526.exe'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "Wondershare PDF Password Remover (Build $($this.CurrentState.Version))"
      ProductCode = '{1719FAD6-2F6A-4F5E-BF2B-1F6F6F1E3806_PasswordRemover}_is1'
    }
  )
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
