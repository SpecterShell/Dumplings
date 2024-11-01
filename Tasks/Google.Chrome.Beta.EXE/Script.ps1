# x64
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x64" />
  <app appid="{8237E44A-0054-442C-B6B6-EA0509993955}" version="" ap="x64">
    <updatecheck />
  </app>
</request>
'@

# x86
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x86" />
  <app appid="{8237E44A-0054-442C-B6B6-EA0509993955}" version="" ap="x86">
    <updatecheck />
  </app>
</request>
'@

# arm64
$Object3 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="arm64" />
  <app appid="{8237E44A-0054-442C-B6B6-EA0509993955}" version="" ap="arm64">
    <updatecheck />
  </app>
</request>
'@

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.response.app.updatecheck.manifest.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object2.response.app.updatecheck.manifest.version)")
  $this.Log("x64 version: $($Object1.response.app.updatecheck.manifest.version)")
  $this.Log("arm64 version: $($Object3.response.app.updatecheck.manifest.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = ($Object2.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object2.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = ($Object3.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object3.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
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
