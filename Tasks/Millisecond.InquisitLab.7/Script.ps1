$Object1 = Invoke-RestMethod -Uri "https://lab.millisecond.com/inquisit6/checkupdate?iqversion=$($this.Status.Contains('New') ? '7.2.0' : $this.LastState.Version)" -Headers @{ 'X-Api-Key' = $Global:DumplingsSecret.InquisitLabKey }

# Version
$this.CurrentState.Version = $Object1.Version
$VersionParts = $this.CurrentState.Version.Split('.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = "https://inquisit.millisecond.com/$($VersionParts[0])/$($VersionParts[0])_$($VersionParts[1])/win/Inquisit_$($VersionParts -join '').exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.millisecond.com/products/releasenotes' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'container-fluid')]/div[contains(./span[@class='h3'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./span[@class="h5"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'div' -and $Node.SelectSingleNode('./span[@class="h3"]')); $Node = $Node.NextSibling) { $Node }
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
