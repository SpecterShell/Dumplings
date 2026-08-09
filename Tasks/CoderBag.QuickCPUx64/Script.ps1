$Prefix = 'https://coderbag.com/product/quickcpu'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Latest Version:\s*(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.outerHTML -match 'Download Quick CPU Free' } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.Content, 'Released:\s*(\d{1,2}\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (en-US)
      $Object2 = Invoke-WebRequest -Uri 'https://coderbag.com/product/quickcpu/release-notes' | ConvertFrom-Html
      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@class, 'group-box') and contains(./div[contains(@class, 'header')], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[contains(@class, "content")]') | Get-TextContent | Format-Text
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

    if (-not $this.Status.Contains('New')) {
      # Old version auto-update. The publisher serves the current release from the
      # versionless 'currentversion' URL and publishes a versioned URL under
      # 'release/<version>/' only after a newer version becomes current. Re-point
      # the previous version's manifest to its versioned release URL so it keeps
      # serving the correct installer. IgnorePRCheck is required because that
      # version's pull request was already opened by the first submit above.
      $this.CurrentState = $this.LastState
      $this.CurrentState.Installer = @(
        [ordered]@{
          Architecture = 'x64'
          InstallerUrl = "https://coderbag.com/assets/downloads/cpm/release/$($this.CurrentState.Version)/QuickCpuSetup-$($this.CurrentState.Version).msi"
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
