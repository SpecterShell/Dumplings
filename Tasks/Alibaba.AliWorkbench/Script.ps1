$Object1 = Invoke-RestMethod -Uri 'https://hudong.alicdn.com/api/data/v2/f11f572338d74092b8d87bf32791bbc0.js' | Get-EmbeddedJson -StartsFrom '$QNPortalData=' | ConvertFrom-Json

# x86
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.WindowsVersion.x32
}
$VersionX86 = [regex]::Match($InstallerUrlX86, 'qianniu_\((.+)\)').Groups[1].Value

# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.WindowsVersion.x64
}
$VersionX64 = [regex]::Match($InstallerUrlX64, 'qianniu_\((.+)\)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $Object1.iterativeDiary.Where({ $_.end.Contains('Windows') }, 'First')[0].diaryList.Where({ $_.versionTitle.Contains([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d)').Groups[1].Value) }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].versionContent | ConvertFrom-Html | Get-TextContent | Format-Text
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
  'Updated' {
    $this.Submit()
  }
}
