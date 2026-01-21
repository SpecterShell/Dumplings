$Object1 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = Join-Uri 'https://image.lceda.cn/' $Object1.SelectSingleNode('//a[contains(@data-url, ".exe") and contains(@data-url, "ia32") and not(contains(@data-url, "pro"))]').Attributes['data-url'].Value
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = Join-Uri 'https://image.lceda.cn/' $Object1.SelectSingleNode('//a[contains(@data-url, ".exe") and contains(@data-url, "x64") and not(contains(@data-url, "pro"))]').Attributes['data-url'].Value
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://lceda.cn/page/update-record' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new(($Object2.SelectSingleNode('//*[contains(@class, "doc-body-left")]') | Get-TextContent))

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String -match "^v?$([regex]::Escape($this.CurrentState.Version))") {
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -match '^(20\d{2}\.\d{1,2}\.\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif ($String -notmatch '^v?(\d+(?:\.\d+)+)') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3.Close()
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
