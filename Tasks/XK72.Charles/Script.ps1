$Session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$Object1 = Invoke-WebRequest -Uri 'https://www.charlesproxy.com/download/latest-release/' -WebSession $Session | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//form[@class="download-form"]//input[@name="version"]').Attributes['Value'].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.charlesproxy.com/latest-release/download.do' -Method Post -Body @{
  __csrf  = $Session.Cookies.GetAllCookies().Where({ $_.Name -eq 'cactuslab.csrf' }, 'First')[0].Value
  os      = 'windows64'
  beta    = 'false'
  version = $this.CurrentState.Version
} -WebSession $Session | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://www.charlesproxy.com$([regex]::Match($Object2.SelectSingleNode('//meta[@http-equiv="refresh"]').Attributes['content'].Value, 'url=(.+)').Groups[1].Value)" | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMSIX

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.charlesproxy.com/documentation/version-history/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='content']/h4[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTimeNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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
