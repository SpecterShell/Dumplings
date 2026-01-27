$Prefix = 'https://files.gpg4win.org/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;P=*.exe;F=0"

$InstallerName = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_ -match '^gpg4win-[\d\.]+(-\d+)?\.exe$' } | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, 'gpg4win-([\d\.]+(-\d+)?)\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://gpg4win.org/change-history.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='main']/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2' -and -not $Node.InnerText.Contains('Explicit download of this version'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
