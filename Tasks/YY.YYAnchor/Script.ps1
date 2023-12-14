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
  throw "Task $($Task.Name): $($Object1.message)"
}

$Object2 = Invoke-RestMethod -Uri "http://forceupdate.yy.com$($Object1.data.configPath)"

# Version
$Task.CurrentState.Version = $Object2.Product.Version.VerNo

# UniVer
$Task.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://yydl.yy.com/$($Object2.Product.Version.Pack.FileUrl)"
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.discription | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
