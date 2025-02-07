$Object1 = Invoke-RestMethod -Uri 'https://updates.bravesoftware.com/service/update2' -Method Post -Body @"
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" updaterversion="1.3.361.137" ismachine="0" sessionid="{$((New-Guid).Guid)}" testsource="auto" requestid="{$((New-Guid).Guid)}">
    <os platform="win" version="10" sp="" arch="x64" />
    <app appid="{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}" ap="x86-rel" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}" ap="x64-rel" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
    <app appid="{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}" ap="arm64-rel" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
</request>
"@

if (@($Object1.response.app.updatecheck.manifest.version | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1.response.app[0].updatecheck.manifest.version)")
  $this.Log("x64 version: $($Object1.response.app[1].updatecheck.manifest.version)")
  $this.Log("arm64 version: $($Object1.response.app[2].updatecheck.manifest.version)")
  throw 'Inconsistent versions detected'
}

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
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/brave/brave-browser/master/CHANGELOG_DESKTOP.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(.//text(), '$($this.CurrentState.Version.Split('.')[1..3] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -creplace 'Released \d{4}-\d{1,2}-\d{1,2}\n' | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
