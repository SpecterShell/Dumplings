# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-x64-user/stable/latest'
# x64 machine
# $Object2 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-x64/stable/latest'
# arm64 user
# $Object3 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-arm64-user/stable/latest'
# arm64 machine
# $Object4 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/update/win32-arm64/stable/latest'

# if ($Object1.productVersion -ne $Object2.productVersion) {
#   $this.Log("Inconsistent x64 versions: user: $($Object1.productVersion), machine: $($Object2.productVersion)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url | ConvertTo-Https
  # ProductCode  = '{33B7C9E1-F1A4-4505-8E86-6A45DEE8AC9A}_is1'
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   Scope        = 'machine'
#   InstallerUrl = $Object2.url | ConvertTo-Https
#   ProductCode  = '{E03E77F0-C06C-44D5-BFF1-33EDBBE21F3B}_is1'
# }
# if ($Object1.productVersion -eq $Object3.productVersion) {
#   if ($Object3.productVersion -eq $Object4.productVersion) {
#     $this.CurrentState.Installer += [ordered]@{
#       Architecture = 'arm64'
#       Scope        = 'user'
#       InstallerUrl = $Object3.url | ConvertTo-Https
#       ProductCode  = '{38B31348-0F09-4613-975A-530CB8749398}_is1'
#     }
#     $this.CurrentState.Installer += [ordered]@{
#       Architecture = 'arm64'
#       Scope        = 'machine'
#       InstallerUrl = $Object4.url | ConvertTo-Https
#       ProductCode  = '{157D79C6-9B5E-4D97-8982-BE405FBF92F6}_is1'
#     }
#   } else {
#     $this.Log("arm64 user version: $($Object3.productVersion)")
#     $this.Log("arm64 machine version: $($Object4.productVersion)")
#     $this.Log('Inconsistent arm64 versions detected. The arm64 installers will be ignored', 'Warning')
#   }
# } else {
#   $this.Log("x64 user version: $($Object1.productVersion)")
#   $this.Log("arm64 user version: $($Object3.productVersion)")
#   $this.Log('Inconsistent x64 and arm64 versions detected. The arm64 installers will be ignored', 'Warning')
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

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[(self::h2 or self::h3) and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove download links table
        $Object3.SelectNodes("//main//table[contains(., '下载安装包')]").ForEach({ $_.Remove() })
        # Remove help letter space
        $Object3.SelectNodes('//span[@class="help-letter-space"]').ForEach({ $_.Remove() })
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h2', 'h3'); $Node = $Node.NextSibling) { $Node }
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
  { $_.Contains('Changed') -and -not $_.Contains('Updated') } {
    $this.Config.IgnorePRCheck = $true
  }
  'Updated' {
    $this.Submit()
  }
}
