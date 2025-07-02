$Global:DumplingsStorage.ZWSOFTApps = Invoke-RestMethod -Uri 'https://www.zwsoft.cn/index.php?g=Api&m=Common&a=getDownloadCenterProduct' -Method Post -Body @{
  environment    = 'pc'
  system         = 'Windows'
  page           = '1'
}
