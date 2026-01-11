# en-US
$Prefix = 'https://www.dreamsourcelab.com/download/'
$Object1 = Invoke-WebRequest -Uri $Prefix
# zh-CN
$PrefixCN = 'https://dreamsourcelab.cn/download/'
$Object2 = Invoke-WebRequest -Uri $PrefixCN

# x86 en-US
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86') -and $_.href -match 'DSView' } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64 en-US
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x64') -and $_.href -match 'DSView' } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x86 zh-CN
$this.CurrentState.Installer += $InstallerX86CN = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $PrefixCN $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86') -and $_.href -match 'DSView' } catch {} }, 'First')[0].href
}
$VersionX86CN = [regex]::Match($InstallerX86CN.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64 zh-CN
$this.CurrentState.Installer += $InstallerX64CN = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $PrefixCN $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x64') -and $_.href -match 'DSView' } catch {} }, 'First')[0].href
}
$VersionX64CN = [regex]::Match($InstallerX64CN.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionX86CN, $VersionX64CN) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 en-US version: ${VersionX86}")
  $this.Log("x64 en-US version: ${VersionX64}")
  $this.Log("x86 zh-CN version: ${VersionX86CN}")
  $this.Log("x64 zh-CN version: ${VersionX64CN}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = $Object1 | ConvertFrom-Html
      $Object4 = [System.IO.StringReader]::new(($Object3.SelectSingleNode("//h4[contains(text(), 'DSView Changelogs')]/following::text()[contains(., 'v$($this.CurrentState.Version)')][1]/ancestor::div[@class='wpb_wrapper']") | Get-TextContent))

      while ($Object4.Peek() -ne -1) {
        $String = $Object4.ReadLine()
        if ($String.Contains("v$($this.CurrentState.Version)")) {
          if ($String -match '(20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object4.ReadLine()
          break
        }
      }
      if ($Object4.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object4.Peek() -ne -1) {
          $String = $Object4.ReadLine()
          if ($String -notmatch '^v\d+(\.\d+)+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object4.Close()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object5 = $Object2 | ConvertFrom-Html
      $Object6 = [System.IO.StringReader]::new(($Object5.SelectSingleNode("//h4[contains(text(), 'DSView软件更新日志')]/following::text()[contains(., 'v$($this.CurrentState.Version)')][1]/ancestor::div[@class='wpb_wrapper']") | Get-TextContent))

      while ($Object6.Peek() -ne -1) {
        $String = $Object6.ReadLine()
        if ($String.Contains("v$($this.CurrentState.Version)")) {
          if ($String -match '(20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object6.ReadLine()
          break
        }
      }
      if ($Object6.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object6.Peek() -ne -1) {
          $String = $Object6.ReadLine()
          if ($String -notmatch '^v\d+(\.\d+)+') {
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
