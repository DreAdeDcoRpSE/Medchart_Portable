<?php
// Refresh the existing 30-minute inactivity timer only after an authenticated,
// CSRF-protected user interaction. Never resurrect an expired session.
require_once __DIR__ . '/../includes/security.php';
require_once __DIR__ . '/../includes/db.php';
header('Content-Type: application/json; charset=utf-8');
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    http_response_code(405);
    exit(json_encode(['ok' => false]));
}
med_require_csrf();
med_require_user($conn);
header('Cache-Control: no-store');
echo json_encode(['ok' => true]);
