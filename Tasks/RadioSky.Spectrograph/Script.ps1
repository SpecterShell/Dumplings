$Object1 = Invoke-WebRequest -Uri 'https://radiosky.com/spec/spectrographnews.txt'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Latest Spectrograph version: (\d+(?:\.\d+)+)').Groups[1].Value -replace '\d+', { ([int]$_.Value).ToString() }

$Object2 = [System.IO.StreamReader]::new($Object1.RawContentStream)

while (-not $Object2.EndOfStream) {
  $String = $Object2.ReadLine()
  if ($String.StartsWith("Version $($this.CurrentState.Version)")) {
    break
  }
}
if (-not $Object2.EndOfStream) {
  $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
  while (-not $Object2.EndOfStream) {
    $String = $Object2.ReadLine()
    if ($String -match '^https?://') {
      $this.CurrentState.Installer += [ordered]@{
        InstallerUrl = $String | ConvertTo-Https
      }
    } elseif ($String -match '^_+$') {
      break
    } elseif ($String -notmatch 'Double\W+Click') {
      $ReleaseNotesObjects.Add($String)
    }
  }
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesObjects | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

try {
  $Object2.Close()
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object1.Content, 'Spectrograph News (\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'MM/dd/yyyy',
        $null
      ).ToString('yyyy-MM-dd')
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
