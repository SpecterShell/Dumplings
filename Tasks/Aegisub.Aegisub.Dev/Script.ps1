$Prefix = 'http://plorkyeran.com/aegisub/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

$ReleaseNotesTitle = $Object1.SelectSingleNode('/html/body/h3[1]').InnerText

# Version
$this.CurrentState.Version = [regex]::Match($ReleaseNotesTitle, '(r[\d]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object1.SelectSingleNode('/html/body/div[1]/a[1]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object1.SelectSingleNode('/html/body/div[2]/a[1]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($ReleaseNotesTitle, '(\d{2}/\d{2}/\d{2})').Groups[1].Value,
        'MM/dd/yy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectSingleNode('/html/body/ul[2]') | Get-TextContent | Format-Text
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
