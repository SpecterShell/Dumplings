$Global:DumplingsStorage.AWSCloudHSMDownloadPage = Invoke-WebRequest -Uri 'https://docs.aws.amazon.com/cloudhsm/latest/userguide/latest-releases.html'
$Global:DumplingsStorage.AWSCloudHSMDownloadPageObject = $Global:DumplingsStorage.AWSCloudHSMDownloadPage | ConvertFrom-Html
