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

$Identical = $true
if (($Object1.response.app.updatecheck.manifest.version | Sort-Object -Unique).Count -gt 1) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://brave.com/latest/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'hero__content')]/div[./h2[@id='desktop']]/h3[contains(@id, '$(($this.CurrentState.Version.Split('.') | Select-Object -Skip 1) -join '')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesTitleNode.SelectSingleNode('./text()[2]').InnerText,
          '\((.+)\)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'p' -and -not $Node.Attributes['id'].Value?.Contains('release-notes') ; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -creplace '\(Changelog for [\d\.]+\)', '' | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
