$Object1 = Invoke-WebRequest -Uri 'https://u.tools/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerUrl           = $InstallerUrlX86 = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('ia32') } catch {} }, 'First')[0].href
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = ($VersionX86 = [regex]::Match($InstallerUrlX86, '-([\d\.]+)[-\.]').Groups[1].Value) + '-ia32'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $InstallerUrlX64 = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('ia32') } catch {} }, 'First')[0].href
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $VersionX64 = [regex]::Match($InstallerUrlX64, '-([\d\.]+)[-\.]').Groups[1].Value
    }
  )
}

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
      $Object2 = Invoke-WebRequest -Uri 'https://u.tools/docs/guide/changelog.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//main//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          if ($Node.InnerText.Contains('发布时间')) {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($Node.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $Node
          }
        }
        # ReleaseNotes (zh-CN)
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
