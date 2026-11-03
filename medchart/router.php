<?php
// Security router for PHP's built-in development server (localhost only).
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$decoded = rawurldecode((string)$path);
if (strpos($decoded, "\0") !== false || strpos(str_replace('\\','/',$decoded), '..') !== false) {
    http_response_code(403); exit('Forbidden');
}
$segments = explode('/', trim(str_replace('\\','/',$decoded), '/'));
foreach ($segments as $segment) {
    if ($segment !== '' && $segment[0] === '.') { http_response_code(403); exit('Forbidden'); }
}
if (preg_match('~(?:^|/)(?:secret|includes|install/schema\.php|router\.php|libs/dompdf/vendor)(?:/|$)~i', $decoded)) {
    // Allow installer PHP pages, but never direct reads of includes or secrets.
    http_response_code(403); exit('Forbidden');
}
if (preg_match('~\.(?:sql|sqlite|db|log|ini|conf|bak|zip|medchart|env|json|md)$~i', $decoded)) {
    http_response_code(403); exit('Forbidden');
}
return false;
