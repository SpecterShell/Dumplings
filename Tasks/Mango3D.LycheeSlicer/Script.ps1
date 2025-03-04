$Prefix = 'https://mango-lychee.nyc3.digitaloceanspaces.com/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://mango3d.io/change-log-lychee-slicer/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@class, 'et_builder_inner_content')]/div[contains(@class, 'et_pb_with_background') and contains(., '$($this.CurrentState.Version)')]/following-sibling::div[contains(@class, 'et_pb_section')][1]//div[contains(@class, 'et_pb_column')][1]")
      if ($ReleaseNotesNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "et_pb_text")][1]')
        try {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTimeNode.InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } catch {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
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
