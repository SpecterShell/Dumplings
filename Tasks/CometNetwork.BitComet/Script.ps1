$Object1 = Invoke-RestMethod -Uri 'https://update.bitcomet.com/client/bitcomet/'

# Version
$Task.CurrentState.Version = $Object1.BitComet.AutoUpdate.UpdateGroupList.LatestDownload.file1.'#text'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.bitcomet.com/achive/BitComet_$($Task.CurrentState.Version)_setup.exe"
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/en/changelog' | ConvertFrom-Html
    $Object3 = Invoke-WebRequest -Uri 'https://www.bitcomet.com/cn/changelog' | ConvertFrom-Html

    try {
      $ReleaseNotesTitle = $Object2.SelectSingleNode('/html/body/div/div/dl/dt[1]').InnerText
      if ($ReleaseNotesTitle.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitle, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('/html/body/div/div/dl/dt[1]/following-sibling::dd[count(.|/html/body/div/div/dl/dt[2]/preceding-sibling::dd)=count(/html/body/div/div/dl/dt[2]/preceding-sibling::dd)]').InnerText | Format-Text | ConvertTo-UnorderedList
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    try {
      $ReleaseNotesTitle = $Object3.SelectSingleNode('/html/body/div/div/dl/dt[1]').InnerText
      if ($ReleaseNotesTitle.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3.SelectNodes('/html/body/div/div/dl/dt[1]/following-sibling::dd[count(.|/html/body/div/div/dl/dt[2]/preceding-sibling::dd)=count(/html/body/div/div/dl/dt[2]/preceding-sibling::dd)]').InnerText | Format-Text | ConvertTo-UnorderedList
        }
      } else {
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
