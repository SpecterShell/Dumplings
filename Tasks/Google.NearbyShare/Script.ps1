$Object = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x64" />
  <app appid="{232066FE-FF4D-4C25-83B4-3F8747CF7E3A}">
    <updatecheck />
  </app>
</request>
'@

# Version
$Task.CurrentState.Version = $Object.response.app.updatecheck.manifest.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' })[0].run
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
