$Prefix = 'https://sfc-repo.snowflakecomputing.com/snowflake-cli/windows_x86_64/index.html'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix = Join-Uri $Prefix ($Object1.Links.Where({ try { $_.href -match '^\d+(?:\.\d+)+/' } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1)

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesUrl = "https://docs.snowflake.com/en/release-notes/clients-drivers/snowflake-cli-$((Get-Date).Year)"
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      # Remove anchors
      $Object4.SelectNodes('.//a[@class="headerlink"]').ForEach({ $_.Remove() })

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h2[contains(., 'Version $($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
