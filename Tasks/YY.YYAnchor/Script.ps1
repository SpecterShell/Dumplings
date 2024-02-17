$UniVer = '12C0F000'
$Time = Get-Date -Format 'yyyyMMddHHmmss'
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes(
      (('YXBwaWQ9eXlhbmNob3ImdGltZXN0YW1wPXswfSZrPUJQWDQlcElTY3pETDVyZF4yb3QmMVNSanBGN0AwaEVU' | ConvertFrom-Base64) -f $Time)
    )
  )
).Replace('-', '').ToLower()
$Object1 = Invoke-RestMethod -Uri "https://up.yy.com/api/check/yyanchor/check4update?timestamp=${Time}&sourceVersion=${UniVer}&n=${Hash}&manual=1"

if ($Object1.code -ne 0) {
  throw "Task $($this.Name): $($Object1.message)"
}

$Object2 = Invoke-RestMethod -Uri "http://forceupdate.yy.com$($Object1.data.configPath)"

# Version
$this.CurrentState.Version = $Object2.Product.Version.VerNo

# UniVer
$this.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = "https://yydl.yy.com/$($Object2.Product.Version.Pack.FileUrl)"
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.discription | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
