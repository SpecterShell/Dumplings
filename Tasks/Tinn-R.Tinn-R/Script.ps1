$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://tinn-r.org/update/new_version.txt' | Join-String -Separator "`n"

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '(\d{1}\.\d{2}\.\d{2}\.\d{2})(?=_(setup.exe|portable.zip))').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '0+(?=\d)'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1 | Split-LineEndings)[0].Trim()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::Parse([regex]::Match($Object1, '(\d{2}-\w{3}-\d{4} \d{2}:\d{2})').Groups[1].Value, (Get-Culture -Name 'pt')) | ConvertTo-UtcDateTime -Id 'E. South America Standard Time'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://tinn-r.org/en/download' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//blockquote[contains(./h5/text(), '$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'blockquote'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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
