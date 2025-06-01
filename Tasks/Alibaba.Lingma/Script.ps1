# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-x64-user/stable/latest'
# x64 machine
# $Object2 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-x64/stable/latest'
# arm64 user
$Object3 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-arm64-user/stable/latest'
# arm64 machine
# $Object4 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-arm64/stable/latest'

# if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
if (@(@($Object1, $Object3) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
  $this.Log("x64 user version: $($Object1.productVersion)")
  # $this.Log("x64 machine version: $($Object2.productVersion)")
  $this.Log("arm64 user version: $($Object3.productVersion)")
  # $this.Log("arm64 machine version: $($Object4.productVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url | ConvertTo-Https
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   Scope        = 'machine'
#   InstallerUrl = $Object2.url | ConvertTo-Https
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object3.url | ConvertTo-Https
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   Scope        = 'machine'
#   InstallerUrl = $Object4.url | ConvertTo-Https
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://help.aliyun.com/zh/lingma/product-overview/changelogs-of-lingma-ide' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//main//h2[contains(., 'v$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove download links table
        $Object3.SelectNodes("//main//table[contains(., '下载安装包')]").ForEach({ $_.Remove() })
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
