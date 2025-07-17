$Prefix = 'http://www.graphmatica.com/home.html'
$Object1 = Invoke-WebRequest -Uri $Prefix

$InstallerUrlLink = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrlLink.outerHTML, 'Graphmatica (\d+(?:\.[a-zA-Z0-9]+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = $InstallerUrl = Join-Uri $Prefix $InstallerUrlLink.href
}
$Filename = $InstallerUrl | Split-Path -LeafBase
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'da'
  InstallerUrl    = Join-Uri $InstallerUrl "dansk/${Filename}-dk.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'el'
  InstallerUrl    = Join-Uri $InstallerUrl "greek/${Filename}-gr.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  InstallerUrl    = Join-Uri $InstallerUrl "espanol/${Filename}-es.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fa'
  InstallerUrl    = Join-Uri $InstallerUrl "farsi/${Filename}-fa.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  InstallerUrl    = Join-Uri $InstallerUrl "francais/${Filename}-fr.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it'
  InstallerUrl    = Join-Uri $InstallerUrl "italiano/${Filename}-it.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pl'
  InstallerUrl    = Join-Uri $InstallerUrl "polski/${Filename}-pl.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pt-BR'
  InstallerUrl    = Join-Uri $InstallerUrl "pt-br/${Filename}-pt-BR.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'sv'
  InstallerUrl    = Join-Uri $InstallerUrl "swedish/${Filename}-sv.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'http://www.graphmatica.com/whatsnew.html'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//tr[contains(./td[2], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($ReleaseNotesNode.SelectSingleNode('./td[1]').InnerText, 'M/d/yy', $null).ToString('yyyy-MM-dd')

        $ReleaseNotesUrlNode = $ReleaseNotesNode.SelectSingleNode('./td[3]//a')
        if ($ReleaseNotesUrlNode) {
          # ReleaseNotesUrl (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotesUrl'
            Value  = $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl = $ReleaseNotesUrlNode.Attributes['href'].Value
          }

          $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
          $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), `"What's new`") and contains(text(), '$($this.CurrentState.Version)')]")
          if ($ReleaseNotesTitleNode) {
            # ReleaseNotes (en-US)
            $this.CurrentState.Locale += [ordered]@{
              Locale = 'en-US'
              Key    = 'ReleaseNotes'
              Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="boxed"]') | Get-TextContent | Format-Text
            }
          } else {
            # ReleaseNotes (en-US)
            $this.CurrentState.Locale += [ordered]@{
              Locale = 'en-US'
              Key    = 'ReleaseNotes'
              Value  = $ReleaseNotesNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
            }
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
          }
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
