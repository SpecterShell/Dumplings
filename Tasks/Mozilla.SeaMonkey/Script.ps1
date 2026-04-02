# The following locales can't be matched by WinGet properly and thus are omitted: ach (Acholi/Acoli), cak (Kaqchikel), ia (Interlingua), lij (Ligurian), sc (Sardinian), sco (Scots), son (Songhai), szl (Silesian), trs (Triqui)
$Locales = @('en-US', 'cs', 'de', 'el', 'en-GB', 'es-AR', 'es-ES', 'fi', 'fr', 'hu', 'it', 'ja', 'ka', 'nb-NO', 'nl', 'pl', 'pt-BR', 'pt-PT', 'ru', 'sk', 'sv-SE', 'zh-CN', 'zh-TW')
$ArchMap = [ordered]@{
  x64 = 'win64'
}
$Prefix = 'https://s3.osuosl.org/seamonkey-archive/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://s3.osuosl.org/seamonkey-archive/?delimiter=/&prefix=releases/'

# Version
$this.CurrentState.Version = $Version = $Object1.ListBucketResult.CommonPrefixes.Prefix -replace '^releases/' -replace '/$' -match '^(\d+(?:\.\d+)+)$' | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
foreach ($Locale in $Locales) {
  foreach ($Arch in $ArchMap.GetEnumerator()) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale = $Locale
      Architecture    = $Arch.Key
      InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${Locale}/seamonkey-${Version}.${Locale}.$($Arch.Value).installer.exe"
      ProductCode     = "SeaMonkey ${Version} ($($Arch.Key) ${Locale})"
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.seamonkey-project.org/news'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://www.seamonkey-project.org/news-atom').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].updated | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].content.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2[0].link.href | ConvertTo-Https
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
