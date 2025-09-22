<?php
// Dossier de stockage
$storage_dir = '/var/data/browser_data/';

// Vérifier et créer le dossier si nécessaire
if (!file_exists($storage_dir)) {
    mkdir($storage_dir, 0700, true);
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Récupérer l'IP client (avec gestion des proxies)
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'];
    
    // Nettoyer l'IP pour le nom de fichier
    $clean_ip = str_replace([':', '.'], ['-', '_'], $ip);
    
    // Générer un nom de fichier unique
    $filename = sprintf(
        "%s%s_%s.txt",
        $storage_dir,
        $clean_ip,
        date('Ymd_His')
    );

    $data = file_get_contents('php://input');
    
    if ($data) {
	umask(0002);
        // Écrire dans un nouveau fichier
        if (file_put_contents($filename, $data) !== false) {
            echo "Données sauvegardées dans : " . basename($filename);
        } else {
	    http_response_code(500);
            echo "Erreur d'écriture dans le fichier.";
        }
    } else {
	http_response_code(400);
        echo 'Aucune donnée reçue.';
    }
} else {
    http_response_code(405);
    echo 'Méthode non autorisée.';
}
?>
