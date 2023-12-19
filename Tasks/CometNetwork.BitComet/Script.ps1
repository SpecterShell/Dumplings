$Object1 = Invoke-RestMethod -Uri 'https://update.bitcomet.com/client/bitcomet/'

# Version
$this.CurrentState.Version = $Object1.BitComet.AutoUpdate.UpdateGroupList.LatestDownload.file1.'#text'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.bitcomet.com/achive/BitComet_$($this.CurrentState.Version)_setup.exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/en/changelog' | ConvertFrom-Html
    $Object3 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/cn/changelog' | ConvertFrom-Html

    try {
      $ReleaseNotesTitle = $Object2.SelectSingleNode('/html/body/div/div/dl/dt[1]').InnerText
      if ($ReleaseNotesTitle.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('/html/body/div/div/dl/dt[1]/following-sibling::dd[count(.|/html/body/div/div/dl/dt[2]/preceding-sibling::dd)=count(/html/body/div/div/dl/dt[2]/preceding-sibling::dd)]').InnerText | Format-Text | ConvertTo-UnorderedList
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    try {
      $ReleaseNotesTitle = $Object3.SelectSingleNode('/html/body/div/div/dl/dt[1]').InnerText
      if ($ReleaseNotesTitle.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('/html/body/div/div/dl/dt[1]/following-sibling::dd[count(.|/html/body/div/div/dl/dt[2]/preceding-sibling::dd)=count(/html/body/div/div/dl/dt[2]/preceding-sibling::dd)]').InnerText | Format-Text | ConvertTo-UnorderedList
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
