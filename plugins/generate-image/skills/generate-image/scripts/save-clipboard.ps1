param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath
)

Add-Type -AssemblyName System.Windows.Forms
$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($img) {
    $img.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "OK"
} else {
    Write-Host "NO_IMAGE"
}
