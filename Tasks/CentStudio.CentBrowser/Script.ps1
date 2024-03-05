# International x86
$RequestX86 = [System.Net.WebRequest]::Create('https://www.centbrowser.com/update.php?switches&cb-check-update&version=4.3.9.248')
$RequestX86.AllowAutoRedirect = $false
$ResponseX86 = $RequestX86.GetResponse()

# International x64
$RequestX64 = [System.Net.WebRequest]::Create('https://www.centbrowser.com/update.php?switches&64bit&cb-check-update&version=4.3.9.248')
$RequestX64.AllowAutoRedirect = $false
$ResponseX64 = $RequestX64.GetResponse()

# Chinese x86
$RequestCNX86 = [System.Net.WebRequest]::Create('https://www.centbrowser.cn/update.php?switches&cb-check-update&version=4.3.9.248')
$RequestCNX86.AllowAutoRedirect = $false
$ResponseCNX86 = $RequestCNX86.GetResponse()

# Chinese x64
$RequestCNX64 = [System.Net.WebRequest]::Create('https://www.centbrowser.cn/update.php?switches&64bit&cb-check-update&version=4.3.9.248')
$RequestCNX64.AllowAutoRedirect = $false
$ResponseCNX64 = $RequestCNX64.GetResponse()

$Identical = $true
if (@(@($ResponseX86, $ResponseX64, $ResponseCNX86, $ResponseCNX64) | Sort-Object -Property { $_.GetResponseHeader('Cent-Version') } -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $ResponseCNX64.GetResponseHeader('Cent-Version')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $ResponseX86.GetResponseHeader('Location') | ConvertTo-Https
}
$ResponseX86.Close()

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $ResponseX64.GetResponseHeader('Location') | ConvertTo-Https
}
$ResponseX64.Close()

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $ResponseCNX86.GetResponseHeader('Location') | ConvertTo-Https
}
$ResponseCNX86.Close()

$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $ResponseCNX64.GetResponseHeader('Location') | ConvertTo-Https
}
$ResponseCNX64.Close()

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-WebRequest -Uri 'https://www.centbrowser.com/history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object1.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.centbrowser.cn/history.html' | ConvertFrom-Html

      $ReleaseNotesCNNode = $Object2.SelectSingleNode("//html/body/div[2]/div/div[contains(./p/text()[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match(
          $ReleaseNotesCNNode.SelectSingleNode('./p/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectSingleNode('./span') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
