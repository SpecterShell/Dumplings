$Object1 = Invoke-WebRequest -Uri 'https://www.irfanview.com/checkversion.php' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('/html/body/b[1]').InnerText.Trim().PadRight(4, '0')

# Installer
# The links on the homepage requires referer. Use TechSpot mirror for the links.
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://files02.tchspt.com/down/iview$($this.CurrentState.Version.Replace('.', ''))_setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://files02.tchspt.com/down/iview$($this.CurrentState.Version.Replace('.', ''))_x64_setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.irfanview.com/main_history.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='inner-content']/h3[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul') | Get-TextContent | Format-Text
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
