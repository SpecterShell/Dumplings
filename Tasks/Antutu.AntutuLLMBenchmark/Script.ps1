$Object1 = Invoke-RestMethod -Uri 'https://file.antutu.com/ai/aitutu_pc_v1.dat'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$InstallerUrlRaw = [uri]$Object1.url
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("$($InstallerUrlRaw.AbsolutePath)$($Global:DumplingsSecret.AntutuKey)2147483647")
  )
).Replace('-', '').ToLower()
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrlRaw.AbsoluteUri + '?auth_key=' + $Hash + '&expires=2147483647'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
