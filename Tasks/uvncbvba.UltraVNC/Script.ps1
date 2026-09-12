$Prefix = 'https://uvnc.com/downloads/ultravnc.html'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//th[@class="list-title"]/a')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'UltraVNC (\d+(?:\.\d+){3})').Groups[1].Value

$Object3 = Invoke-WebRequest -Uri ($Prefix = Join-Uri $Prefix $Object2.Attributes['href'].Value) | ConvertFrom-Html
$Object4 = Invoke-WebRequest -Uri (Join-Uri $Prefix $Object3.SelectSingleNode("//div[contains(@class, 'jd_content') and contains(./div[contains(@class, 'jd_download_title')], '$($this.CurrentState.Version)') and contains(./div[contains(@class, 'jd_download_title')], 'X86') and not(contains(./div[contains(@class, 'jd_download_title')], 'msi'))]//div[contains(@class, 'jd_url_download_right')]//a").Attributes['href'].Value).Replace('/summary/', '/send/')
$Object5 = Invoke-WebRequest -Uri (Join-Uri $Prefix $Object3.SelectSingleNode("//div[contains(@class, 'jd_content') and contains(./div[contains(@class, 'jd_download_title')], '$($this.CurrentState.Version)') and contains(./div[contains(@class, 'jd_download_title')], 'X64') and not(contains(./div[contains(@class, 'jd_download_title')], 'msi'))]//div[contains(@class, 'jd_url_download_right')]//a").Attributes['href'].Value).Replace('/summary/', '/send/')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = [regex]::Match($Object4.Content, "document.location.href='([^']+?)'").Groups[1].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [regex]::Match($Object5.Content, "document.location.href='([^']+?)'").Groups[1].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      if ($ReleaseNotesUrlLink = $Object1.SelectSingleNode('//a[contains(@href, "//forum.uvnc.com/viewtopic.php")]')) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $ReleaseNotesUrlLink.Attributes['href'].Value
        }

        $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='content']/node()[contains(., 'Changelog')]/following-sibling::node()[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch '^\s*(?:Version)?\s*\d+(?:\.\d+)+' -and -not ($Node.Name -eq 'br' -and $Node.NextSibling.Name -eq 'br'); $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
