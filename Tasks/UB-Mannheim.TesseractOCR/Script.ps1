$Prefix = 'https://digi.bib.uni-mannheim.de/tesseract/'

$Content = (Invoke-WebRequest -Uri "${Prefix}?C=M;O=D;F=0;P=*.exe").Content

# Version
$Task.CurrentState.Version = [regex]::Match($Content, 'tesseract-ocr-w64-setup-(v[\d\.]+)\.exe').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${Prefix}tesseract-ocr-w32-setup-$($Task.CurrentState.Version).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}tesseract-ocr-w64-setup-$($Task.CurrentState.Version).exe"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($Task.CurrentState.Version, '(\d{8})').Groups[1].Value,
  'yyyyMMdd',
  $null
).ToString('yyyy-MM-dd')

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/wiki/UB-Mannheim/tesseract/Home.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object2.SelectSingleNode("/ul[2]/li[contains(./text(), '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./text()').InnerText | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
