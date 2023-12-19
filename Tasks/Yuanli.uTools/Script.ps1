$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://u.tools/')

$Prefix = $EdgeDriver.ExecuteScript('return publishURL', $null)
$Object1 = $EdgeDriver.ExecuteScript('return publishPlatform', $null)

$Identical = $true
if ($Object1.'win-x64'.version -ne $Object1.'win-ia32'.version) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.'win-x64'.version, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object1.'win-ia32'.package
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object1.'win-x64'.package
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # ReleaseNotesUrl
    $ReleaseNotesUrl = Get-RedirectedUrl -Uri "https://open.u-tools.cn/redirect?target=update_description&version=$($this.CurrentState.Version)"
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl
    }

    $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('/html/body/h2[1]').InnerText.Contains($this.CurrentState.Version)) {
        if ($Object2.SelectSingleNode('/html/body/h2[2]')) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object2.SelectNodes('/html/body/p[1]/following-sibling::node()[count(.|/html/body/h2[2]/preceding-sibling::node())=count(/html/body/h2[2]/preceding-sibling::node())]') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $Object2.SelectNodes('/html/body/p[1]/following-sibling::*') | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
