$Object1 = Invoke-WebRequest -Uri 'https://www.internetdownloadmanager.com/download.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href | ConvertTo-HtmlDecodedText | Split-Uri -LeftPart Path
}

$VersionMatches = [regex]::Match($InstallerUrl, 'idman((\d)(\d+)build(\d+))')

# Version
$this.CurrentState.Version = $VersionMatches.Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    # The version can only be obtained from the ARP registry after installation
    # The installer is not totally silent (a messagebox will popup when the software is running)
    # Use ThreadJob with a timeout to avoid being stuck, and the script will fail in the next expression
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/skipdlgs' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $this.CurrentState.RealVersion = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Internet Download Manager' -Name 'DisplayVersion'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.internetdownloadmanager.com/news.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'col-center')]/h3[contains(text(), '$($VersionMatches.Groups[2].Value).$($VersionMatches.Groups[3].Value) Build $($VersionMatches.Groups[4].Value)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[@class="subtext"][1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTimeNode.InnerText, '([a-zA-Z]+\W+\d{1,2},\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
