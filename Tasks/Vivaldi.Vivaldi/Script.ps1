# x86
$Object1 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/public/appcast.xml'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://update.vivaldi.com/update/1.0/public/appcast.x64.xml'

# Version
$this.CurrentState.Version = $Object2.enclosure.version

$Identical = $true
if ($Object1.enclosure.version -ne $Object2.enclosure.version) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.enclosure.url.Replace('stable-auto', 'stable')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.enclosure.url.Replace('stable-auto', 'stable')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $Object2.releaseNotesLink
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      if ($this.LastState.Contains('Version')) {
        $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/html/body/h2[contains(text(), '$($this.LastState.Version -creplace '(\d+\.\d+)\.(\d+\.\d+)', '$1 ($2)')')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = @()
          for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
            $ReleaseNotesNodes += $Node
          }
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
