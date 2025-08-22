$Object1 = Invoke-RestMethod -Uri 'https://www.linkease.com/downloads/client-version/'

# Version
$this.CurrentState.Version = $Object1.versions.Where({ $_.prop -eq 'Win' }, 'First')[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://fw.koolcenter.com/binary/LinkEase/Client/LinkEaseSetupWin32.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://fw.koolcenter.com/binary/LinkEase/Client/LinkEaseSetup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = "https://doc.linkease.com/zh/guide/linkease/changelog/$($this.CurrentState.Version).html"

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      # Remove link buttons
      $Object2.SelectNodes('//span[@class="sr-only"]').ForEach({ $_.Remove() })
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//main/div[contains(@class, "content__default")]/h3[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
