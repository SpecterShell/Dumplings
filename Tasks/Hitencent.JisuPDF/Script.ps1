$Object1 = Invoke-WebRequest -Uri 'https://jisupdf.com/zh-cn/pdf-reader.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/div[1]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      try {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object1.SelectSingleNode('//*[@id="reader-jisupdf"]/div[1]/p[3]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }

      $Object2 = (Invoke-WebRequest -Uri 'https://upd.jisupdf.com/version.php' | Read-ResponseContent -Encoding GBK).Replace('**', "`n") | ConvertFrom-StringData

      if ($Object2.v -eq $this.CurrentState.Version) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.GetEnumerator() | Where-Object -Property Key -CMatch -Value '^t\d+$' | Sort-Object -Property Key | Select-Object -ExpandProperty Value | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
