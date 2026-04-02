$Object1 = Invoke-RestMethod -Uri 'https://api.atlassian.com/acli/api/v1/version'

# Version
$this.CurrentState.Version = $Object1.latestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = "https://acli.atlassian.com/windows/$($this.CurrentState.Version)/acli_$($this.CurrentState.Version)_windows_amd64.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "acli_$($this.CurrentState.Version)_windows_amd64\acli.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerUrl         = "https://acli.atlassian.com/windows/$($this.CurrentState.Version)/acli_$($this.CurrentState.Version)_windows_arm64.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "acli_$($this.CurrentState.Version)_windows_arm64\acli.exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://developer.atlassian.com/cloud/acli/changelog/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h4[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./preceding::h2[1]').InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following::div[contains(@class, "ak-renderer-wrapper")]') | Get-TextContent | Format-Text
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
