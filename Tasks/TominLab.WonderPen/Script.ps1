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

switch (Compare-State) {
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
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
