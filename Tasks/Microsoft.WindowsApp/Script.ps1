$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/windows-app/whats-new' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 32-bit")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 64-bit")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows Arm64")]').Attributes['href'].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//section[@id='tabpanel_2_windows']/h3[text()='Version $($this.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::node()[contains(., "Date published:")]')
        if ($ReleaseTimeNode) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseTimeNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
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
