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
  throw "Task $($this.Name): The response content from the API is empty"
}

$Object2 = Invoke-RestMethod -Uri "http://forceupdate.yy.com$($Content1 | Split-LineEndings | Select-Object -First 1)"

# Version
$this.CurrentState.Version = $Object2.Product.Version.Dir

# UniVer
$this.CurrentState.UniVer = $Object2.Product.Version.UniVer

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://yydl.yy.com/4/setup/YYSetup-$($this.CurrentState.Version)-zh-CN.exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Content3 = Invoke-WebRequest -Uri "https://forceupdate.yy.com/$($Object2.Product.Version.VersionNote)" | Read-ResponseContent

    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Content3 | Split-LineEndings | Select-Object -Skip 1 | Format-Text
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
