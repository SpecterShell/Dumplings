$Prefix = 'https://digi.bib.uni-mannheim.de/tesseract/'

$Object1 = (Invoke-WebRequest -Uri "${Prefix}?C=M;O=D;F=0;P=*.exe").Content

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'tesseract-ocr-w64-setup-([\d\.]+)\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${Prefix}tesseract-ocr-w32-setup-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}tesseract-ocr-w64-setup-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($this.CurrentState.Version, '(\d{8})').Groups[1].Value,
        'yyyyMMdd',
        $null
      ).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/wiki/UB-Mannheim/tesseract/Home.md' | Convert-MarkdownToHtml

      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object2.SelectSingleNode("/ul[2]/li[contains(./text(), '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./text()').InnerText | Format-Text
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
