# International x86
$Request1 = [System.Net.WebRequest]::Create('https://www.centbrowser.com/update.php?switches&cb-check-update&version=4.3.9.248')
$Request1.AllowAutoRedirect = $false
$Response1 = $Request1.GetResponse()

# International x64
$Request2 = [System.Net.WebRequest]::Create('https://www.centbrowser.com/update.php?switches&64bit&cb-check-update&version=4.3.9.248')
$Request2.AllowAutoRedirect = $false
$Response2 = $Request2.GetResponse()

# Chinese x86
$Request3 = [System.Net.WebRequest]::Create('https://www.centbrowser.cn/update.php?switches&cb-check-update&version=4.3.9.248')
$Request3.AllowAutoRedirect = $false
$Response3 = $Request3.GetResponse()

# Chinese x64
$Request4 = [System.Net.WebRequest]::Create('https://www.centbrowser.cn/update.php?switches&64bit&cb-check-update&version=4.3.9.248')
$Request4.AllowAutoRedirect = $false
$Response4 = $Request4.GetResponse()

# Version
$this.CurrentState.Version = $Response4.GetResponseHeader('Cent-Version')

$Identical = $true
if ((@($Response1, $Response2, $Response3, $Response4) | Sort-Object -Property { $_.GetResponseHeader('Cent-Version') } -Unique).Count -gt 1) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Response1.GetResponseHeader('Location') | ConvertTo-Https
}
$Response1.Close()

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Response2.GetResponseHeader('Location') | ConvertTo-Https
}
$Response2.Close()

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Response3.GetResponseHeader('Location') | ConvertTo-Https
}
$Response3.Close()

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Response4.GetResponseHeader('Location') | ConvertTo-Https
}
$Response4.Close()

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = Invoke-WebRequest -Uri 'https://www.centbrowser.com/history.html' | ConvertFrom-Html
    $Object2 = Invoke-WebRequest -Uri 'https://www.centbrowser.cn/history.html' | ConvertFrom-Html

    try {
      $ReleaseNotesNode1 = $Object1.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode1) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode1.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode1.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $ReleaseNotesNode2 = $Object2.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match(
          $ReleaseNotesNode2.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode2.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
