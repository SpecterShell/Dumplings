$Object1 = (((Invoke-WebRequest -Uri 'https://www.feishu.cn/hc/zh-CN/articles/360049067543').Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).Values | ForEach-Object -Process { if ($_ -is [array]) { $_ } } | Where-Object -FilterScript { $_ -is [System.Collections.IDictionary] -and $_.Contains('html') } | Select-Object -First 1).html.html | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.msi') -and $_.href -match 'ia32' } catch {} }, 'First')[0].href
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.msi') -and $_.href -match 'x64' } catch {} }, 'First')[0].href
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Warning')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.feishu.cn/hc/en-US/articles/360043073734'
      }

      $Object2 = ((Invoke-WebRequest -Uri 'https://www.feishu.cn/hc/en-US/articles/360043073734').Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

      $ReleaseNotesNode = $Object2[0].Value.Where({ $_.html.html.Contains("V$($this.CurrentState.Version.Split('.')[0..1] -join '.')") }, 'First')
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode[0].html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//text()[contains(., "Updated")]|.//hr'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.feishu.cn/hc/zh-CN/articles/360043073734'
      }

      $Object3 = ((Invoke-WebRequest -Uri 'https://www.feishu.cn/hc/zh-CN/articles/360043073734').Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

      $ReleaseNotesCNNode = $Object3[0].Value.Where({ $_.html.html.Contains("V$($this.CurrentState.Version.Split('.')[0..1] -join '.')") }, 'First')
      if ($ReleaseNotesCNNode) {
        $ReleaseNotesCNTitleNode = ($ReleaseNotesCNNode[0].html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//text()[contains(., "发布于")]|.//hr'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesCNTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
