$Object1 = Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/check-update?app=wonderpen'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-ia32'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-x64'
}

if (!$InstallerUrl1.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl1}`ndoesn't contain version $($this.CurrentState.Version)"
}
if (!$InstallerUrl2.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl2}`ndoesn't contain version $($this.CurrentState.Version)"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/update-detail?app=wonderpen').data | Where-Object -Property 'version' -EQ -Value $this.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2.date_ms | ConvertFrom-UnixTimeMilliseconds

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.desc.en | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.desc.cn | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
