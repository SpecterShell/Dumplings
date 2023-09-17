for ($i = 0; $i -lt 10; $i++) {
  $Object = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x64" />
  <app appid="{6BBAE539-2232-434A-A4E5-9A33560C6283}">
    <updatecheck />
  </app>
</request>
'@
  if ($Object.response.app.cohortname -eq 'Stable') {
    break
  }
  Start-Sleep 1
}

if ($Object.response.app.cohortname -ne 'Stable') {
  throw "Task $($Task.Name): Could not fetch stable version. Current cohort is $($Object.response.app.cohortname)"
}

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
