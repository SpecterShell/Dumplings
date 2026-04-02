$Object1 = Invoke-WebRequest -Uri 'https://tools.veracode.com/veracode-cli/LATEST_VERSION' | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://tools.veracode.com/veracode-cli/veracode_v$($this.CurrentState.Version)_windows_386.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "veracode-cli_$($this.CurrentState.Version)_windows_386\veracode.exe" })
  InstallerUrl         = "https://tools.veracode.com/veracode-cli/veracode-cli_$($this.CurrentState.Version)_windows_386.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "veracode-cli_$($this.CurrentState.Version)_windows_x86\veracode.exe" })
  InstallerUrl         = "https://tools.veracode.com/veracode-cli/veracode-cli_$($this.CurrentState.Version)_windows_x86.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://docs.veracode.com/updates/r/Veracode_CLI_Updates'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }

        if ($ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./preceding-sibling::h2[1]')) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseTimeNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notmatch '^h\d$'; $Node = $Node.NextSibling) { $Node }
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
