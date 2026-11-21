$Object1 = (Invoke-RestMethod -Uri 'https://developer.nvidia.com/cuda-downloads.json').data.releases.'Windows/x86_64/11/exe_local'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.filename, 'cuda_([\d\.]+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object1.details | ConvertFrom-Html).SelectSingleNode('//a[contains(@href, ".exe")]').Attributes['href'].Value
  ProductCode  = "{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}_CUDAToolkit_$($this.CurrentState.RealVersion)"
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
