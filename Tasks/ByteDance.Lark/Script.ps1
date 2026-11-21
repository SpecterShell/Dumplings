$Object1 = Invoke-RestMethod -Uri 'https://www.larksuite.com/api/downloads'
# x86
$Object2 = $Object1.versions.Windows
$VersionX86 = [regex]::Match($Object2.version_number, 'V([\d\.]+)').Groups[1].Value
# x64
$Object3 = $Object1.versions.Windows_x64
$VersionX64 = [regex]::Match($Object3.version_number, 'V([\d\.]+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Warning')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.download_link
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.download_link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.larksuite.com/hc/en-US/articles/360046836333'
      }

      $Object2 = ((Invoke-WebRequest -Uri 'https://www.larksuite.com/hc/en-US/articles/360046836333').Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

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

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
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
        Value  = 'https://www.larksuite.com/hc/zh-CN/articles/360046836333'
      }

      $Object3 = ((Invoke-WebRequest -Uri 'https://www.larksuite.com/hc/zh-CN/articles/360046836333').Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

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
