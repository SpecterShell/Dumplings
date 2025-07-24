$Prefix = 'https://updates.victronenergy.com/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}SoftwareInfo.txt" | Split-LineEndings

$i = 1
$Found = $false
for ($i = 1; $i -lt $Object1.Count; $i += 10) {
  if ($Object1[$i] -eq 'VE Configuration tools') {
    $Found = $true
    break
  }
}
if (-not $Found) {
  $this.Log('VE Configuration tools not found in the SoftwareInfo.txt', 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1[$i - 1].Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1[$i + 1].Trim()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
