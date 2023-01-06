$UniVer = '9000F002'
$Time = Get-Date -Format 'yyyyMMddHHmmss'
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes(
      (('cGlkPXl5JnN2PXswfSZ0PXsxfSZrPXNsMyRAbDQzI3lHMzR5WSY0UjBERilkI0RUZTZmIXQ1NjQlcmRyNTRqNmpzd2U0ag==' | ConvertFrom-Base64) -f $UniVer, $Time)
    )
  )
).Replace('-', '').ToLower()
$Content1 = Invoke-RestMethod -Uri "https://update.yy.com/check4update?pid=yy&t=${Time}&sv=${UniVer}&f=1&n=${Hash}" -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  throw "Task $($Task.Name): The response content from the API is empty"
}

$Object2 = Invoke-RestMethod -Uri "http://forceupdate.yy.com$($Content1 | Split-LineEndings | Select-Object -First 1)"

# Version
$Task.CurrentState.Version = $Object2.Product.Version.Dir

# UniVer
$Task.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://yydl.yy.com/4/setup/YYSetup-$($Task.CurrentState.Version)-zh-CN.exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Content3 = Invoke-WebRequest -Uri "https://forceupdate.yy.com/$($Object2.Product.Version.VersionNote)" | Read-ResponseContent

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Content3 | Split-LineEndings | Select-Object -Skip 1 | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
