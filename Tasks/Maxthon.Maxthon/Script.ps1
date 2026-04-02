$Object1 = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/bloodchen/mxfast/main/u1.txt'

$Content = [Convert]::FromBase64String($Object1)

$Aes = [System.Security.Cryptography.AesManaged]@{
  Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
  Mode    = [System.Security.Cryptography.CipherMode]::CBC
  Key     = [System.Text.Encoding]::UTF8.GetBytes($Global:DumplingsSecret.MaxthonKey)
  IV      = [byte[]]($Content[0..15])
}
$AesDecryptor = $Aes.CreateDecryptor()

$Object2 = [System.Text.Encoding]::UTF8.GetString($AesDecryptor.TransformFinalBlock($Content, 16, $Content.Length - 16)) | ConvertFrom-Json

$Aes.Dispose()
$AesDecryptor.Dispose()

# Global x86
$Object3 = $Object2.win10.en.maxthon86.Where({ $_.channels -contains 'stable' }, 'First')[0]
# Global x64
$Object4 = $Object2.win10.en.maxthon64.Where({ $_.channels -contains 'stable' }, 'First')[0]
# China x86
$Object5 = $Object2.win10.cn.maxthon86.Where({ $_.channels -contains 'stable' }, 'First')[0]
# China x64
$Object6 = $Object2.win10.cn.maxthon64.Where({ $_.channels -contains 'stable' }, 'First')[0]

if ((@($Object3, $Object4, $Object5, $Object6) | Sort-Object -Property 'version' -Unique).Count -gt 1) {
  $this.Log("Global x86 version: $($Object3.version)")
  $this.Log("Global x64 version: $($Object4.version)")
  $this.Log("China x86 version: $($Object5.version)")
  $this.Log("China x64 version: $($Object6.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object4.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object3.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object4.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  # InstallerUrl    = "https://dl-cn.maxthon.com/mx7/maxthon_$($Object5.version)_x64.exe"
  InstallerUrl    = $Object5.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  # InstallerUrl    = "https://dl-cn.maxthon.com/mx7/maxthon_$($Object6.version)_x64.exe"
  InstallerUrl    = $Object6.url
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
