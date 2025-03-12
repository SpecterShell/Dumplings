# x86
$Object1 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/install/pledit7.htm' | ConvertFrom-Html
$VersionX86 = $Object1.SelectSingleNode('.//meta[@http-equiv="fversion"]').Attributes['content'].Value
# x64
$Object2 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/install/pledit7-64.htm' | ConvertFrom-Html
$VersionX64 = $Object2.SelectSingleNode('.//meta[@http-equiv="fversion"]').Attributes['content'].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.SelectSingleNode('.//meta[@http-equiv="furl"]').Attributes['content'].Value
  ProductCode  = "Golden$($this.CurrentState.Version.Split('.')[0])32_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.SelectSingleNode('.//meta[@http-equiv="furl"]').Attributes['content'].Value
  ProductCode  = "Golden$($this.CurrentState.Version.Split('.')[0])64_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('.//meta[@http-equiv="fdate"]').Attributes['content'].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/pledit.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@id='pledit_history_tabpanel']//h2[contains(text(), 'Version $($this.CurrentState.Version.Split('.')[0..1] -join '.') Build $($this.CurrentState.Version.Split('.')[3])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
