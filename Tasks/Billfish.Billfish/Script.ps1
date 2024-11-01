# x64
$Object1 = Invoke-RestMethod -Uri 'https://front-gw.aunapi.com/applicationService/installer/getAppVersion?appId=10301011&versionCode=0.0.0.0&packageSystemSupport=2'
# x86
$Object2 = Invoke-RestMethod -Uri 'https://front-gw.aunapi.com/applicationService/installer/getAppVersion?appId=10301011&versionCode=0.0.0.0&packageSystemSupport=1'

# Version
$this.CurrentState.Version = $Object1.data.versionCode

$Identical = $true
if ($Object1.data.versionCode -ne $Object2.data.versionCode) {
  $this.Log('Inconsistent versions detected', 'Warning')
  $this.Log("x86 version: $($Object2.data.versionCode)")
  $this.Log("x64 version: $($Object1.data.versionCode)")
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.data.downloadUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.createTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.billfish.cn/help/gengxinrizhi' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[starts-with(@class, 'catalog_catalogContent')]/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node -and $Node.Name -ne 'hr'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
