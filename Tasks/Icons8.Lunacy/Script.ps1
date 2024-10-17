$Object1 = Invoke-WebRequest -Uri 'https://lcdn.icons8.com/setup/version.win.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  # InstallerUrl = "https://lcdn.icons8.com/setup/LunacySetup_$($this.CurrentState.Version).exe"
  InstallerUrl = 'https://lcdn.icons8.com/setup/LunacySetup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://lcdn.icons8.com/setup/LunacySetup_arm64.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://lunacy.docs.icons8.com/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='content']/h2[text()='$($this.CurrentState.Version.Split('.')[0..1] -join '.')']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          if ($Node.InnerText.Contains('Release date')) {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($Node.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+\d{1,4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } elseif (-not $Node.SelectSingleNode('.//a[contains(@href, "lcdn.icons8.com") or contains(@href, "snapcraft.io") or contains(@href, "9pnlmkkpcljj") or contains(@href, "id1582493835")]')) {
            $Node
          }
        }
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
