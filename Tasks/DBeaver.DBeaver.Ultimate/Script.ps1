$Object1 = Invoke-RestMethod -Uri 'https://dbeaver.com/product/dbeaver-ue-version.xml'

# Version
$this.CurrentState.Version = $Object1.version.number

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = "https://downloads.dbeaver.net/ultimate/$($this.CurrentState.Version)/dbeaver-ue-$($this.CurrentState.Version)-x86_64-setup.exe"
  ProductCode  = 'DBeaverUltimate (current user)'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = "https://downloads.dbeaver.net/ultimate/$($this.CurrentState.Version)/dbeaver-ue-$($this.CurrentState.Version)-x86_64-setup.exe"
  ProductCode  = 'DBeaverUltimate'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.version.date, 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.version.'release-notes'.'#cdata-section' | Format-Text
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
