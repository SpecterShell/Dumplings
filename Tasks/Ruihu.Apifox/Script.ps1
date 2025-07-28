# x86
$Object1 = Invoke-RestMethod -Uri "https://api.apifox.cn/api/v1/configs/client-updates/$($this.Status.Contains('New') ? '2.6.43' : $this.LastState.Version)/win32/latest.yml?noCache=$(Get-Random)" -Headers @{
  'x-system-version'                  = '10.0.22000'
  'x-running-under-arm64-translation' = 'false'
  'x-platform'                        = 'win32'
  'x-arch'                            = 'x86'
} | ConvertFrom-Yaml
# x64
$Object2 = Invoke-RestMethod -Uri "https://api.apifox.cn/api/v1/configs/client-updates/$($this.Status.Contains('New') ? '2.6.43' : $this.LastState.Version)/win64/latest.yml?noCache=$(Get-Random)" -Headers @{
  'x-system-version'                  = '10.0.22000'
  'x-running-under-arm64-translation' = 'false'
  'x-platform'                        = 'win64'
  'x-arch'                            = 'x64'
} | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("x86 version: $($Object1.version)")
  $this.Log("x64 version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.files[0].url | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.files[0].url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://docs.apifox.com/doc-5807637'
      }

      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@id='$($this.CurrentState.Version.Replace('.', ''))']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -replace '(?s)\s*20\d{2}-\d{1,2}-\d{1,2}' | Format-Text
        }

        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl + '#' + $this.CurrentState.Version.Replace('.', '')
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
