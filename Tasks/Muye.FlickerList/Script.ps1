$Object1 = Invoke-WebRequest -Uri 'https://nartick.com/'
$AppScriptUrl = 'https:' + [regex]::Match($Object1.Content, '//static\.flicker\.cool/flicker-home/static/js/app\.[0-9a-f]+\.js').Value
$Object2 = Invoke-WebRequest -Uri $AppScriptUrl
$Match = [regex]::Match($Object2.Content, '="(\d+(?:\.\d+)+)",\w+="([^"]*)",\w+="nartick://"')

$Prefix = "https://static.flicker.cool/flicker/download/stable/$($Match.Groups[1].Value)$($Match.Groups[2].Value)/win32/"
$Object3 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}$($Object3.files[0].url)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releaseDate | Get-Date -AsUTC
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
