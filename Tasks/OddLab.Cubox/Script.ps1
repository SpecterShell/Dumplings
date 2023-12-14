$Object1 = Invoke-RestMethod -Uri 'https://cubox-official-resource.s3.us-west-1.amazonaws.com/desktop/update.json'
$Object2 = Invoke-RestMethod -Uri 'https://update.cubox.pro/update.json'

# Version
$Task.CurrentState.Version = $Object1.version

if ($Object1.version -ne $Object2.version) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = "Cubox_$($Task.CurrentState.Version)_x64_en-US.msi"
    }
  )
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale      = 'zh-CN'
  InstallerUrl         = $Object2.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = "Cubox_$($Task.CurrentState.Version)_x64_zh-CN.msi"
    }
  )
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime() ?? $Object2.pub_date.ToUniversalTime()

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
