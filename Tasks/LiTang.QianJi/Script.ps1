$Object1 = Invoke-RestMethod -Uri 'https://upkit.qianji.app/qj/windows.txt'

# Version
$this.CurrentState.Version = $Object1.version.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.version.downloadUrl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.version.changeLogs | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # $Object2 = Invoke-WebRequest -Uri 'https://docs.qianjiapp.com/change-log/change_log_pc.html' | ConvertFrom-Html

    # try {
    #   $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='book-search-results']/div[1]/section/h2[contains(./text(), '$($this.CurrentState.Version)-$($Object1.versionCode)')]")
    #   if ($ReleaseNotesNode) {
    #     # ReleaseTime
    #     $this.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./following-sibling::p[1]').InnerText | Get-Date -Format 'yyyy-MM-dd'
    #   } else {
    #     $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    #   }
    # } catch {
    #   $this.Logging($_, 'Warning')
    # }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
