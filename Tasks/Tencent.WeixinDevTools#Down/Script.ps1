$Prefix = 'https://developers.weixin.qq.com/miniprogram/dev/devtools/stable.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$InstallerUrlX86 = $Object1.Links.Where({ try { $_.href.Contains('win32_ia32') } catch {} }, 'First')[0].href
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = (Get-RedirectedUrl -Uri $InstallerUrlX86).Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$VersionX86 = [regex]::Match($InstallerUrlX86, 'download_version=(\d+)').Groups[1].Value
$VersionX86Length = $VersionX86.Length
$VersionX86 = $VersionX86.Insert($VersionX86Length - 7, '.').Insert($VersionX86Length - 9, '.')

$InstallerUrlX64 = $Object1.Links.Where({ try { $_.href.Contains('win32_x64') } catch {} }, 'First')[0].href
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = (Get-RedirectedUrl -Uri $InstallerUrlX64).Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$VersionX64 = [regex]::Match($InstallerUrlX64, 'download_version=(\d+)').Groups[1].Value
$VersionX64Length = $VersionX64.Length
$VersionX64 = $VersionX64.Insert($VersionX64Length - 7, '.').Insert($VersionX64Length - 9, '.')

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1 | ConvertFrom-Html

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Prefix + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
      }

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(@id, '$($this.CurrentState.Version.Replace('.', '-'))') and contains(@id, '更新说明')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Prefix + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
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
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockWeixinDevTools')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("WeixinDevTools-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["WeixinDevTools-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
