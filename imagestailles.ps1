function Show-Spinner {
    while (-not $global:StopSpinner) {
        foreach ($char in '|/-\') {
            Write-Host "`r$char" -NoNewline
            Start-Sleep -Milliseconds 100
        }
    }
    Write-Host "`r " -NoNewline # Clear the spinner at the end
}

function Start-Spinner {
    $global:StopSpinner = $false
    $global:runspace = [runspacefactory]::CreateRunspace()
    $global:runspace.Open()
    $powershell = [powershell]::Create().AddScript({ Show-Spinner })
    $powershell.Runspace = $global:runspace
    $handle = $powershell.BeginInvoke()
}

function Stop-Spinner {
    $global:StopSpinner = $true
    if ($global:runspace) {
        $global:runspace.Close()
    }
}

function Get-ExternalDrives {
    # return Get-Volume  | Where-Object { $_.DriveType -eq 'Removable' -and $_.FileSystem -eq 'FAT32' }
    return Get-Volume
}

function Show-ExternalDrives {
    param($drives)
    Write-Host "Disques amovibles disponibles:" -ForegroundColor Green
    foreach ($drive in $drives) {
        Write-Host ("Lettre: " + $drive.DriveLetter + "`t" + "Taille: " + $drive.SizeRemaining + "/" + $drive.Size + "`t" + "Type de système de fichiers: " + $drive.FileSystem) -ForegroundColor Cyan
    }
}

function Grant-PermissionsToDrive {
    param($driveLetter)
    
    # Demande de confirmation
    $confirmChangePermission = Read-Host "Etes-vous sûr de vouloir changer les permissions de ${driveLetter}? (Oui/Non)"
    if ($confirmChangePermission -ne 'Oui') {
        Write-Host "Modification des permissions annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-Host "Le module NTFSSecurity est nécessaire pour continuer. Installation en cours..." -ForegroundColor Yellow
        Install-Module -Name NTFSSecurity -Confirm:$false -Force

        if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
            Write-Host "Echec de l'installation du module NTFSSecurity. Exécution interrompue." -ForegroundColor Red
            return
        }
    }

    try {
        Add-NTFSAccess -Path "${driveLetter}:\\" -Account $env:USERNAME -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles
        Write-Host "Permissions accordées avec succès." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de l'octroi des permissions. Exécution interrompue." -ForegroundColor Red
        return
    }
}

function Select-Drive {
    $externalDrives = Get-ExternalDrives
    if (-not $externalDrives) {
        Write-Host "Aucun disque amovible trouvé." -ForegroundColor Red
        exit
    }
    Show-ExternalDrives -drives $externalDrives

    $selected = Read-Host "Entrez la lettre du disque que vous souhaitez utiliser"
    if ($externalDrives.DriveLetter -contains $selected) {
        return $selected
    }
    else {
        Write-Host "Lettre de lecteur invalide." -ForegroundColor Red
        exit
    }
}

$selectedDrive = Select-Drive

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Attention: Ce script n'est pas exécuté avec des privilèges d'administrateur." -ForegroundColor Yellow
    Write-Host "Il est possible que certaines opérations échouent en raison de restrictions d'accès." -ForegroundColor Yellow
    $response = Read-Host "Souhaitez-vous continuer malgré cela? (Oui/Non)"
    if ($response -ne 'Oui') {
        Write-Host "Exécution interrompue." -ForegroundColor Red
        exit
    }
}

Grant-PermissionsToDrive -driveLetter $selectedDrive

# Récupération des fichiers, copie des fichiers, etc.
$drivePath = "${selectedDrive}:"

# Emplacement du fichier de log
$logFile = "log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$imageExtensions = @("*.jpg", "*.jpeg")

# Enregistrement de l'heure de début
$startDateTime = Get-Date

Write-Host "Récupération des fichiers en cours..." -ForegroundColor Yellow
Start-Spinner

$destinationFolder = "${selectedDrive}:\UniqueFiles"

$files = Get-ChildItem -Recurse $drivePath -Include $imageExtensions -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "${destinationFolder}\*" }

$totalFilesBeforeHashing = $files.Count
$totalSizeBeforeHashing = ($files | Measure-Object -Property Length -Sum).Sum / 1MB
Stop-Spinner

Write-Host "Filtrage des fichiers pour ne garder que les uniques..." -ForegroundColor Yellow
Start-Spinner

$hashTable = @{}
$uniqueFiles = $files | Where-Object {
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $hashBytes = $md5.ComputeHash([System.IO.File]::ReadAllBytes($_.FullName))
    $hashString = [BitConverter]::ToString($hashBytes) -replace '-'

    if ($hashTable.ContainsKey($hashString)) {
        $false
    }
    else {
        $hashTable[$hashString] = $true
        $true
    }
}

$totalFilesAfterHashing = $uniqueFiles.Count
$totalSizeAfterHashing = ($uniqueFiles | Measure-Object -Property Length -Sum).Sum / 1MB
Stop-Spinner

# Vérification de l'espace disque avant de commencer la copie
$totalSizeRequired = ($uniqueFiles | Measure-Object -Property Length -Sum).Sum
$freeSpaceOnDrive = (Get-Volume -DriveLetter $selectedDrive).SizeRemaining

if ($totalSizeRequired -gt $freeSpaceOnDrive) {
    Write-Host "Espace insuffisant sur le disque. Exécution interrompue." -ForegroundColor Red
    exit
}

# Demandez à l'utilisateur s'il souhaite copier les fichiers uniques
$choice = Read-Host "Vous êtes sur le point de copier $totalFilesAfterHashing fichiers pour un total de $totalSizeAfterHashing MB vers $destinationFolder. Etes-vous sûr? (Oui/Non)"

if ($choice -eq 'Oui') {
    Write-Host "Création du dossier destination..." -ForegroundColor Yellow

    # Gestion d'erreur pour la création du dossier
    try {
        if (-not (Test-Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory
        }
    }
    catch {
        Write-Host "Erreur lors de la création du dossier de destination. Exécution interrompue." -ForegroundColor Red
        exit
    }

    Write-Host "Copie des fichiers en cours..." -ForegroundColor Yellow
    Start-Spinner

    foreach ($file in $uniqueFiles) {
        $destinationPath = Join-Path $destinationFolder $file.Name
        try {
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
        }
        catch {
            Write-Host "Erreur lors de la copie du fichier $($file.FullName). Ce fichier sera ignoré." -ForegroundColor Yellow
        }
    }
    Stop-Spinner
    $copyMessage = "Les fichiers uniques ont été copiés dans $destinationFolder"
    Write-Host $copyMessage -ForegroundColor Green
}
else {
    $copyMessage = "Les fichiers n'ont pas été copiés."
    Write-Host $copyMessage -ForegroundColor Red
}

$logMessage = "Ecriture du fichier de log en cours..."
Write-Host $logMessage -ForegroundColor Magenta

# Enregistrement de l'heure de fin
$endDateTime = Get-Date

# Calcul du temps d'exécution
$duration = $endDateTime - $startDateTime

$logContent = @"
---
Date et heure de début: $startDateTime
Nombre de fichiers avant hashage: $totalFilesBeforeHashing
Taille totale avant hashage: {0:N2} MB

Nombre de fichiers après hashage: $totalFilesAfterHashing
Taille totale après hashage: {1:N2} MB

$copyMessage

Durée d'exécution: $duration
---
"@ -f $totalSizeBeforeHashing, $totalSizeAfterHashing

# Écriture du log dans le fichier
Add-Content -Path $logFile -Value $logContent

# Affichage des résultats
Write-Output $logContent

$endMessage = "Fin du script. Bye !"
Write-Host $endMessage -ForegroundColor Green