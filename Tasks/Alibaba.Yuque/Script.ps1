$Object = (Invoke-RestMethod -Uri 'https://app.nlark.com/yuque-desktop/v4/latest.json').stable | Where-Object -Property 'platform' -EQ -Value 'win32'

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.exe_url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.change_logs | Format-Text | ConvertTo-UnorderedList
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # TODO: Get ReleaseTime from ReleaseNote page https://www.yuque.com/yuque/yuque-desktop/changelog

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
