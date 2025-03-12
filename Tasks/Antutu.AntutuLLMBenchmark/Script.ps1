$Object1 = Invoke-WebRequest -Uri 'https://file.antutu.com/ai/aitutu_pc_v1.dat' | Read-ResponseContent | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$InstallerUrlRaw = [uri]$Object1.url
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("$($InstallerUrlRaw.AbsolutePath)$($Global:DumplingsSecret.AntutuKey)2147483647")
  )
).Replace('-', '').ToLower()
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrlRaw.AbsoluteUri + '?auth_key=' + $Hash + '&expires=2147483647'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.changelog.GetEnumerator().Where({ $_.Key.StartsWith('line') }).ForEach({ $_.Value }) | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
