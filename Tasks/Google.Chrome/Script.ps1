# x86
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x86" />
  <app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" version="" ap="x86">
    <updatecheck />
  </app>
</request>
'@

# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x64" />
  <app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" version="" ap="x64">
    <updatecheck />
  </app>
</request>
'@

# arm64
$Object3 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="arm64" />
  <app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" version="" ap="arm64">
    <updatecheck />
  </app>
</request>
'@

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.response.app.updatecheck.manifest.version } -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.response.app.updatecheck.manifest.version)")
  $this.Log("x64 version: $($Object2.response.app.updatecheck.manifest.version)")
  $this.Log("arm64 version: $($Object3.response.app.updatecheck.manifest.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise.msi'
}

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
}

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise_arm64.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
    $this.CurrentState.ETagX86 = $Object1.Headers.ETag[0]

    $Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
    $this.CurrentState.ETagX64 = $Object2.Headers.ETag[0]

    $Object3 = Invoke-WebRequest -Uri $InstallerARM64.InstallerUrl -Method Head
    $this.CurrentState.ETagARM64 = $Object3.Headers.ETag[0]

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETagX86 -ne $this.LastState.ETagX86 -and $this.CurrentState.ETagX64 -ne $this.LastState.ETagX64 -and $this.CurrentState.ETagARM64 -ne $this.LastState.ETagARM64) {
      throw 'Not all installers have been updated'
    }
    $this.Submit()
  }
}
