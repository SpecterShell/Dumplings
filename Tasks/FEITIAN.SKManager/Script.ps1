$Object1 = Invoke-WebRequest -Uri 'https://fido.ftsafe.com/sk-manager-tool-history-version/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//p[contains(./a/@href, ".zip")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object2.SelectSingleNode('.//a[contains(@href, ".zip")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase)/FEITIAN SK Manager.exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $ReleaseNotesNodes = for ($Node = $Object2.NextSibling; $Node -and -not $Node.SelectSingleNode('.//a[contains(@href, ".zip")]'); $Node = $Node.NextSibling) {
        if (-not $Node.InnerText.Contains('Hash:')) {
          $Node
        }
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
