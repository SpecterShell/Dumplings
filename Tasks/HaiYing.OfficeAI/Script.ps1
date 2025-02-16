$Object1 = Invoke-RestMethod -Uri 'https://www.office-ai.cn/update' -Body @{
  id  = 'officeai'
  ver = $this.LastState.Contains('Version') ? $this.LastState.Version : '316'
} | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1._.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1._.update_urls.Split(';')[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.office-ai.cn/static/introductions/officeai/update-log.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//section[@class='chapter' and ./h2[contains(text(), '$($this.CurrentState.RealVersion)')]]/h2")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
