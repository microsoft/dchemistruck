$RegistryPath = "HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
If (!(Test-Path $RegistryPath)) {
  $check=Get-ItemProperty -Path $RegistryPath | Select-Object -ExpandProperty bDisableJavaScript -ErrorAction SilentlyContinue
  If(!$check){
    "Key does not exist"
    exit 1
  }
  Else{
    Switch($check){
      '1'{
      'Java script is disabled'
      }
      '0' {
      'Java script is enabled'
      } 
    }
  }
}
else{ exit 1}
$RegistryPath = "HKLM:\SOFTWARE\Policies\Adobe\Acrobat Acrobat\DC\FeatureLockDown"
If (!(Test-Path $RegistryPath)) {
  $check=Get-ItemProperty -Path $RegistryPath  | Select-Object -ExpandProperty bDisableJavaScript -ErrorAction SilentlyContinue
  If(!$check){
    "Key does not exist"
    exit 1
  }
  Else{
    Switch($check){
      '1'{
      'Java script is disabled'
      }
      '0' {
      'Java script is enabled'
      } 
    }
  }
}
else{ exit 1}