# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x86'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x64'
}

# Version
$Task.CurrentState.Version = [regex]::Match($Task.CurrentState.Installer[1].InstallerUrl, '(\d+\.\d+\.\d+\.\d+)\.msi').Groups[1].Value

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://getquicker.net/changelog?type=Pc&fromQuicker=true' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object3.SelectSingleNode("//*[@id='body']/div/div/div[1]/div/div[contains(./div[1]/div/h1, '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./div[1]/div/span').InnerText | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]/div') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
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
