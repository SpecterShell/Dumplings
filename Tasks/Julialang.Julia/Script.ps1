$Object1 = (Invoke-WebRequest -Uri 'https://julialang-s3.julialang.org/bin/versions.json' | Read-ResponseContent | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value.stable }) | Sort-Object -Property { $_.Key -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Name

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Value.files.Where({ $_.os -eq 'winnt' -and $_.arch -eq 'i686' }, 'First')[0].url
  ProductCode  = "Julia-$($this.CurrentState.Version)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Value.files.Where({ $_.os -eq 'winnt' -and $_.arch -eq 'x86_64' }, 'First')[0].url
  ProductCode  = "Julia-$($this.CurrentState.Version)_is1"
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
