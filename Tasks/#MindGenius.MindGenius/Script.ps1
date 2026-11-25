# The /checkversion/ endpoint is gone (HTTP 404); the download page carries the same
# versionless edge.mindgenius.com installers that the dependent tasks select.
$Global:DumplingsStorage.MindGeniusDownloadPage = Invoke-WebRequest -Uri 'https://www.mindgenius.com/download/' -UserAgent $DumplingsBrowserUserAgent
