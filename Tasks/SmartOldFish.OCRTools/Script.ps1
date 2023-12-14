$Object = Invoke-WebRequest -Uri 'http://ocr.oldfish.cn:6060/update/update.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$Task.CurrentState.Version = $Object.xml.strNowVersion

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.xml.strFullURL | ConvertTo-Https
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.xml.dtNowDate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.xml.strContext | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
