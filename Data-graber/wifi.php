<?php
// Dossier de stockage dédié au Wifi
$storage_dir = '/var/data/wifi_data/';

// Créer le dossier si nécessaire avec permissions restrictives
if (!file_exists($storage_dir)) {
    mkdir($storage_dir, 0700, true);
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Récupération de l'IP réelle (gestion proxy)
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'];
    
    // Nettoyage du nom de fichier
    $clean_ip = str_replace(['.', ':'], ['_', '-'], $ip);
    
    // Nom de fichier unique : IP + timestamp
    $filename = sprintf(
        "%s%s_%s.txt",
        $storage_dir,
        $clean_ip,
        date('Ymd_His')
    );

    $data = file_get_contents('php://input');
    
    if ($data) {
         umask(0002);
        if (file_put_contents($filename, $data) !== false) {
            echo "Données Wifi sauvegardées : " . basename($filename);
        } else {
            http_response_code(500);
            echo "Erreur lors de l'écriture";
        }
    } else {
        http_response_code(400);
        echo 'Données POST vides';
    }
} else {
    http_response_code(405);
    echo 'Méthode non autorisée';
}
?>
