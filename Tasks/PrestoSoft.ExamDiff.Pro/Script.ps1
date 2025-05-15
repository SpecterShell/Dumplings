$Object1 = Invoke-RestMethod -Uri 'https://www.prestosoft.com/latest_versions.txt' | ConvertFrom-Csv -Delimiter '|' -Header @('Name', 'Edition', 'Version', 'ShortVersion', 'ReleaseDate', 'InstallerUrlX86', 'InstallerUrlX64', 'InstallerUrlARM64') | Where-Object -FilterScript { $_.Name -eq 'edp' } | Select-Object -First 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://www.prestosoft.com/download/' ([regex]::Match((ConvertTo-UnescapedUri -Uri $Object1.InstallerUrlX86), 'file=([^&]+)').Groups[1].Value)
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://www.prestosoft.com/download/' ([regex]::Match((ConvertTo-UnescapedUri -Uri $Object1.InstallerUrlX64), 'file=([^&]+)').Groups[1].Value)
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri 'https://www.prestosoft.com/download/' ([regex]::Match((ConvertTo-UnescapedUri -Uri $Object1.InstallerUrlARM64), 'file=([^&]+)').Groups[1].Value)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.prestosoft.com/edp_buildhistory.asp' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
