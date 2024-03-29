$Object1 = Invoke-RestMethod -Uri 'https://www.xmind.net/_api/checkVersion/0?distrib=cathy_win32'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.buildId, '([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.whatsNew.Split("`n`n")[1] | Format-Text
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
