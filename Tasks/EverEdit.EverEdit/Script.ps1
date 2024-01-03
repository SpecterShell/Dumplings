# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x86'
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '_(\d+)_').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x64'
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '_(\d+)_').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

$Identical = $true
if ($VersionX86 -ne $VersionX64) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object1 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=en' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesNode = $Object1 | Where-Object -FilterScript { $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") }
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesNode.createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=zh_cn' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesNode = $Object3 | Where-Object -FilterScript { $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") }
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesNode.createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
