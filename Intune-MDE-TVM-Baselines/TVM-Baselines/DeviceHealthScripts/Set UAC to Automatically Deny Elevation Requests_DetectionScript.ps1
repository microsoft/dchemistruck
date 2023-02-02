$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
If (!(Test-Path $RegistryPath)) {
    $check=Get-ItemProperty -Path $RegistryPath | Select-Object -ExpandProperty ConsentPromptBehaviorUser -ErrorAction SilentlyContinue
    if(!$check){
        "Key does not exist"
        exit 1
    }
    else{
        if($check == 0){exit 0}
        else {exit 1}
    }
}
else{ exit 1}