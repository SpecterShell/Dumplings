# x64
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x64" />
  <app appid="{401C381F-E0DE-4B85-8BD8-3F3F14FBDA57}" version="" ap="x64">
    <updatecheck />
  </app>
</request>
'@
$Version1 = $Object1.response.app.updatecheck.manifest.version

# x86
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x86" />
  <app appid="{401C381F-E0DE-4B85-8BD8-3F3F14FBDA57}" version="" ap="x86">
    <updatecheck />
  </app>
</request>
'@
$Version2 = $Object2.response.app.updatecheck.manifest.version

if ($Version1 -ne $Version2) { throw 'Distinct versions detected' }

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = ($Object2.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object2.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
