$Object1 = Invoke-WebRequest -Uri 'https://jisupdf.com/zh-cn/pdf-reader.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/div[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[3]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-WebRequest -Uri 'https://upd.jisupdf.com/version.php' | Read-ResponseContent -Encoding GBK).Replace('**', "`n") | ConvertFrom-StringData

    try {
      if ($Object2.v -eq $Task.CurrentState.Version) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.GetEnumerator() | Where-Object -Property Key -CMatch -Value '^t\d+$' | Sort-Object -Property Key | Select-Object -ExpandProperty Value | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
