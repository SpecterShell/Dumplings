$Object1 = Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/check-update?app=wonderpen'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-ia32'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-x64'
}

if (!$InstallerUrlX86.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrlX86}`ndoesn't contain version $($this.CurrentState.Version)"
}
if (!$InstallerUrlX64.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrlX64}`ndoesn't contain version $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/update-detail?app=wonderpen').data.Where({ $_.version -eq $this.CurrentState.Version }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].date_ms | ConvertFrom-UnixTimeMilliseconds

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].desc.en | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].desc.cn | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
