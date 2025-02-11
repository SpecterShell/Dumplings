$Object1 = Invoke-RestMethod -Uri 'https://upkit.qianji.app/qj.json'

# Version
$this.CurrentState.Version = $Object1.windows.version.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.windows.version.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.windows.version.changeLogs | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    # $Object2 = Invoke-WebRequest -Uri 'https://docs.qianjiapp.com/change-log/change_log_pc.html' | ConvertFrom-Html

    # try {
    #   $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='book-search-results']/div[1]/section/h2[contains(./text(), '$($this.CurrentState.Version)-$($Object1.versionCode)')]")
    #   if ($ReleaseNotesNode) {
    #     # ReleaseTime
    #     $this.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./following-sibling::p[1]').InnerText | Get-Date -Format 'yyyy-MM-dd'
    #   } else {
    #     $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    #   }
    # } catch {
    #   $this.Log($_, 'Warning')
    # }

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
