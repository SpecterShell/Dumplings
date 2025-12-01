$UniVer = $this.LastState.Contains('UniVer') ? $this.LastState.UniVer : '9000F002'
$Time = Get-Date -Format 'yyyyMMddHHmmss'
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("pid=yy&sv=${UniVer}&t=${Time}&k=$($Global:DumplingsSecret.YYKey)")
  )
).Replace('-', '').ToLower()
$Object1 = Invoke-RestMethod -Uri "https://update.yy.com/check4update?pid=yy&t=${Time}&sv=${UniVer}&f=1&n=${Hash}" -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = Invoke-RestMethod -Uri "https://forceupdate.yy.com$(($Object1 | Split-LineEndings)[0])"

# Version
$this.CurrentState.Version = $Object2.Product.Version.Dir

# UniVer
$this.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://yydl.yy.com/4/setup/YYSetup-$($this.CurrentState.Version)-zh-CN.exe"
  ProductCode  = "YY$($this.CurrentState.Version.Split('.')[0])"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri "https://forceupdate.yy.com/$($Object2.Product.Version.VersionNote)" | Read-ResponseContent

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3 | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockYY')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("YY-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["YY-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
