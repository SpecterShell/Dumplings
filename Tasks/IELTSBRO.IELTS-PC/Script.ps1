$Object1 = Invoke-RestMethod -Uri 'https://ieltsbro.com/hcp/base/base/officeGetConfigInfo'

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.content.pcWindowsUrl, '([\d\.]+)\.exe').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.content.pcWindowsUrl
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://hcp-server.ieltsbro.com/hcp/base/base/getPcUpdateVersion?osType=pc&appVersion=$($Task.LastState.Version ?? '2.1.2')"

    if ($Object2.content.version -eq $Task.CurrentState.Version) {
      try {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.content.description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } catch {
        $Task.Logging($_, 'Warning')
      }

      $Object3 = Invoke-WebRequest -Uri "$($Object2.content.url)/latest.yml" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix "$($Object2.content.url)/" -Locale 'zh-CN'

      try {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object3.ReleaseTime
      } catch {
        $Task.Logging($_, 'Warning')
      }
    } else {
      $Task.Logging("No ReleaseNotes and ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
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
