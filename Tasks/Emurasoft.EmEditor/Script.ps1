# x86
$Object1 = (Invoke-WebRequest -Uri 'https://updates.emeditor.com/emed32_updates5u.txt' | Read-ResponseContent | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('update32') }, 'First')[0].Value
# x64
$Object2 = (Invoke-WebRequest -Uri 'https://updates.emeditor.com/emed64_updates5u.txt' | Read-ResponseContent | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('update64') }, 'First')[0].Value

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("x86 version: $($Object1.Version)")
  $this.Log("x64 version: $($Object2.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.Version

# RealVersion
$this.CurrentState.RealVersion = $Object2.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.URL
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.emeditor.com/blog/'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://www.emeditor.com/category/emeditor-core/feed/').Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')

      if ($Object3) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].encoded.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3[0].link
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
        Value  = 'https://zh-cn.emeditor.com/blog/'
      }

      $Object4 = (Invoke-RestMethod -Uri 'https://zh-cn.emeditor.com/category/emeditor-core/feed/').Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')

      if ($Object4) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object4[0].encoded.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object4[0].link
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
