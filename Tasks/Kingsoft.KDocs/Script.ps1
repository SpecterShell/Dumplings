# Download
$Response = Invoke-RestMethod -Uri 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopVersion,autoDownload'
$Object1 = $Response.data.kdesktopVersion | ConvertFrom-Json
$Object2 = $Response.data.autoDownload | ConvertFrom-Json
$Version1 = [regex]::Match($Object1.win, 'v([\d\.]+)').Groups[1].Value

# Upgrade
$Object3 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kdg/api/v1/configure?idList=kdesktopWinVersion').data.kdesktopWinVersion | ConvertFrom-Json
# $Object3 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kd/api/configure/list?idList=kdesktopWinVersion').data.kdesktopWinVersion | ConvertFrom-Json
$Version2 = $Object3.version

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -gt 0) {
  # Version
  $this.CurrentState.Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object3.url.Replace('1002', '1001')
  }

  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object3.changes | Format-Text
  }
} else {
  # Version
  $this.CurrentState.Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object2.kdesktopWin.1001
  }

  if ($Version1 -eq $Version2) {
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $Object3.changes | Format-Text
    }
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
