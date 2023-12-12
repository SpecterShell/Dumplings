$Object1 = Invoke-RestMethod -Uri 'https://updates.bravesoftware.com/service/update2' -Method Post -Body @"
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" updaterversion="1.3.361.137" ismachine="0" sessionid="{$((New-Guid).Guid)}" testsource="auto" requestid="{$((New-Guid).Guid)}">
    <os platform="win" version="10" sp="" arch="x64" />
    <app appid="{C6CB981E-DB30-4876-8639-109F8933582C}" ap="x86-ni" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{C6CB981E-DB30-4876-8639-109F8933582C}" ap="x64-ni" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{C6CB981E-DB30-4876-8639-109F8933582C}" ap="arm64-ni" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
</request>
"@

if (($Object1.response.app.updatecheck.manifest.version | Sort-Object -Unique).Length -gt 1) {
  Write-Host -Object "Task $($Task.Name): Distinct versions detected" -ForegroundColor Yellow
  $Task.Config.Notes = '检测到不同的版本'
}

# Version
$Task.CurrentState.Version = $Object1.response.app[1].updatecheck.manifest.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.response.app[0].updatecheck.urls.url.codebase + $Object1.response.app[0].updatecheck.manifest.packages.package.name
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.response.app[1].updatecheck.urls.url.codebase + $Object1.response.app[1].updatecheck.manifest.packages.package.name
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.response.app[2].updatecheck.urls.url.codebase + $Object1.response.app[2].updatecheck.manifest.packages.package.name
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
