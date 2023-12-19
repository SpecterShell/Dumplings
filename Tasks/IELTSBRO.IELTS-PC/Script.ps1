$Object1 = Invoke-RestMethod -Uri 'https://ieltsbro.com/hcp/base/base/officeGetConfigInfo'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.content.pcWindowsUrl, '([\d\.]+)\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.content.pcWindowsUrl
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri "https://hcp-server.ieltsbro.com/hcp/base/base/getPcUpdateVersion?osType=pc&appVersion=$($this.LastState.Version ?? '2.1.2')"

    if ($Object2.content.version -eq $this.CurrentState.Version) {
      try {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.content.description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } catch {
        $this.Logging($_, 'Warning')
      }

      $Object3 = Invoke-WebRequest -Uri "$($Object2.content.url)/latest.yml" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix "$($Object2.content.url)/" -Locale 'zh-CN'

      try {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3.ReleaseTime
      } catch {
        $this.Logging($_, 'Warning')
      }
    } else {
      $this.Logging("No ReleaseNotes and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
