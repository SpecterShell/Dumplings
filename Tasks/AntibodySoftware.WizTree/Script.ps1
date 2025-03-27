# Version
$this.CurrentState.Version = [regex]::Match((Invoke-RestMethod -Uri 'https://antibody-software.com/files/wiztreeversion.php'), '(?m)^VERSION=(.+)$').Groups[1].Value.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://diskanalyzer.com/files/wiztree_$($this.CurrentState.Version.Replace('.', '_'))_setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://diskanalyzer.com/whats-new' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[@class='blog-content']/h4[contains(./text(), 'WizTree $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./span/text()').InnerText, '\((\d{1,2}\W+[a-zA-Z]+\W+\d{4})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
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

    if (-not $this.Status.Contains('New')) {
      $this.CurrentState = $this.LastState
      $this.CurrentState.Installer = @(
        [ordered]@{
          InstallerUrl = "https://diskanalyzer.com/files/archive/wiztree_$($this.CurrentState.Version.Replace('.', '_'))_setup.exe"
        }
      )
      $this.ResetMessage()
      $this.Config.IgnorePRCheck = $true
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
