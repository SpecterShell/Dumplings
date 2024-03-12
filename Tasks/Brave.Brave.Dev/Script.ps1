$Object1 = Invoke-RestMethod -Uri 'https://updates.bravesoftware.com/service/update2' -Method Post -Body @"
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" updaterversion="1.3.361.137" ismachine="0" sessionid="{$((New-Guid).Guid)}" testsource="auto" requestid="{$((New-Guid).Guid)}">
    <os platform="win" version="10" sp="" arch="x64" />
    <app appid="{CB2150F2-595F-4633-891A-E39720CE0531}" ap="x86-dev" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{CB2150F2-595F-4633-891A-E39720CE0531}" ap="x64-dev" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{CB2150F2-595F-4633-891A-E39720CE0531}" ap="arm64-dev" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
</request>
"@

if ($Version1 -ne $Version2) { throw 'Distinct versions detected' }

# Version
$this.CurrentState.Version = $Object1.response.app[1].updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.response.app[0].updatecheck.urls.url.codebase + $Object1.response.app[0].updatecheck.manifest.packages.package.name
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.response.app[1].updatecheck.urls.url.codebase + $Object1.response.app[1].updatecheck.manifest.packages.package.name
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.response.app[2].updatecheck.urls.url.codebase + $Object1.response.app[2].updatecheck.manifest.packages.package.name
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
