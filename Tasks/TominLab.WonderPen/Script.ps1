$Object1 = Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/check-update?app=wonderpen'

# Version
$Task.CurrentState.Version = $Object1.data.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-ia32'
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = Get-RedirectedUrl -Uri 'https://www.tominlab.com/to/get-file/wonderpen?key=win-x64'
}

if (!$InstallerUrl1.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl1}`ndoesn't contain version $($Task.CurrentState.Version)"
}
if (!$InstallerUrl2.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl2}`ndoesn't contain version $($Task.CurrentState.Version)"
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://www.tominlab.com/api/product/update-detail?app=wonderpen').data | Where-Object -Property 'version' -EQ -Value $Task.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object2.date_ms | ConvertFrom-UnixTimeMilliseconds

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.desc.en | Format-Text
        }

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.desc.cn | Format-Text
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
