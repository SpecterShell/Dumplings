$Object1 = Invoke-RestMethod -Uri 'https://procore-drive.s3.amazonaws.com/RELEASES'

# Version
$this.CurrentState.Version = $Object1.releases[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://procore-drive.s3.amazonaws.com/ProcoreDriveSetup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releases[0].datePublished.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.procore.com/products/procore-drive/release-notes' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//span[contains(@id, '$($this.CurrentState.Version)')]/following-sibling::h4[1]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
          'MM/dd/yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://zh-sg.support.procore.com/products/procore-drive/release-notes' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("//span[contains(@id, '$($this.CurrentState.Version)')]/following-sibling::h4[1]")
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesCNTitleNode.InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
          'MM/dd/yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
