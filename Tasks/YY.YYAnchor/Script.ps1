$UniVer = $this.LastState.Contains('UniVer') ? $this.LastState.UniVer : '2030F000'
$Time = Get-Date -Format 'yyyyMMddHHmmss'
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("appid=yyanchor&timestamp=${Time}&k=$($Global:DumplingsSecret.YYAnchorKey)")
  )
).Replace('-', '').ToLower()
$Object1 = Invoke-RestMethod -Uri "https://up.yy.com/api/check/yyanchor/check4update?timestamp=${Time}&sourceVersion=${UniVer}&n=${Hash}&manual=1&hdid="

if ($Object1.code -eq 404) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}
if ($Object1.code -ne 0) {
  throw "The server returned an error: $($Object1.message)"
}

$Object2 = Invoke-RestMethod -Uri "https://forceupdate.yy.com$($Object1.data.configPath)"

# Version
$this.CurrentState.Version = $Object2.Product.Version.VerNo

# UniVer
$this.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://yydl.yy.com/$($Object2.Product.Version.Pack.FileUrl)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.discription | Format-Text
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
