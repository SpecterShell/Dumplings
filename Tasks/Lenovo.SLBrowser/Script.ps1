$Object1 = Invoke-RestMethod -Uri 'https://hao.lenovo.com.cn/browser-service-api/release' -Method Post -Body (
  @{
    browserActive  = 0
    browserChannel = '10'
    browserVersion = $this.Status.Contains('New') ? $this.LastState.Version : '9.0.3.1311'
    osBits         = '64'
    sn             = '0'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

if ($Object1.code -eq '40001') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = Invoke-RestMethod -Uri "$($Object1.data.releaseUrl)SLBUpdate.ini" | ConvertFrom-Ini
$Object3 = $Object2.files.GetEnumerator().Where({ $_.Value.Split('#')[2].Contains('\installer\') }, 'First')[0].Value.Split('#')

# Version
$this.CurrentState.Version = $Object3[1]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = "$($Object1.data.releaseUrl)RootPath/SLBInstall/$($Object3[1])/$($Object3[0]).zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $Object3[0]
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.description | Format-Text
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
