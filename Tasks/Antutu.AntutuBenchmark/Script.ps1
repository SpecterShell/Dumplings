$Object1 = Invoke-WebRequest -Uri 'https://www.antutu.com/' | ConvertFrom-Html

$Node = $Object1.SelectNodes('//*[@class="download" and contains(./div/h4/text()[1], "安兔兔评测") and contains(./div/h4/span, "Win")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  $Node.SelectSingleNode('./div/p/text()').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$InstallerUrlRaw = [uri]$Node.SelectSingleNode('./div/a').Attributes['href'].Value
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
      # ReleaseTime
      $this.CurrentState.ReleaseTime = ($Node.SelectSingleNode('./div/p/span').InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'
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
