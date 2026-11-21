$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x64" />
  <app appid="{B210701E-FFC4-49E3-932B-370728C72662}">
    <updatecheck />
  </app>
</request>
'@

if ($Object1.response.app.cohortname -ne 'Stable') {
  $this.Log("The server returned a non-stable cohort name: $($Object1.response.app.cohortname)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.packages.package.name
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
