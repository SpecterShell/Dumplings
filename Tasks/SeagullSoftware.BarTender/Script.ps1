$Object1 = Invoke-WebRequest -Uri 'https://portal.seagullscientific.com/downloads' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//table[@id="btTable"]/tbody/tr[1]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./td[2]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./td[5]//a').Attributes['href'].Value
}

if ($Object2.SelectSingleNode('./td[1]').Attributes.Contains('rowspan') -and $Object2.SelectSingleNode('./td[1]').Attributes['rowspan'].Value -eq 2 -and $Object2.SelectSingleNode('./following-sibling::tr[1]/td[1]').InnerText.Contains('China')) {
  $this.CurrentState.Installer += [ordered]@{
    InstallerLocale = 'zh-CN'
    InstallerUrl    = $Object2.SelectSingleNode('./following-sibling::tr[1]/td[2]//a').Attributes['href'].Value
  }
} else {
  $this.Log('Could not locate the zh-CN installer', 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($Object2.SelectSingleNode('./td[3]').InnerText, '(\d{1,2}/\d{1,2}\W+20\d{2})').Groups[1].Value, 'M/d/yyyy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://support.seagullsoftware.com/hc/sections/360002585073'
      }

      $ReleaseNotesUrlObject = $Object2.SelectSingleNode('./td[2]//a')
      if ($ReleaseNotesUrlObject) {
        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrlObject.Attributes['href'].Value | ConvertFrom-Html

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrlObject.Attributes['href'].Value.Replace('/en-us/', '/') -replace '(/articles/\d+).+$', '$1'
        }

        $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='article-body']/h1[contains(text(), '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
