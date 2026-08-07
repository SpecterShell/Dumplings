$Object1 = Invoke-WebRequest -Uri 'http://www.flowgorithm.org/download/version.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'msi'
  InstallerUrl        = 'http://flowgorithm.org/download/files/Flowgorithm-Setup.zip'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = 'http://flowgorithm.org/download/files/Flowgorithm-exe-only.zip'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'http://flowgorithm.org/documentation/application/revisions.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version -replace '(\.0+)+$')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
