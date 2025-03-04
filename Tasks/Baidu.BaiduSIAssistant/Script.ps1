$Prefix = 'https://fanyiapp.cdn.bcebos.com/tongchuan/assistant/update/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest.yml" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object1.releaseDate,
        "ddd MMM dd yyyy HH:mm:ss 'GMT'K '(GMT'K')'",
        (Get-Culture -Name 'en-US')
      ).ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.detail | Format-Text | ConvertTo-UnorderedList
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
