<?php
// Portable MedChart only: request a graceful local shutdown.
require_once __DIR__ . '/includes/security.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit('Method not allowed');
}
med_require_csrf();

// This endpoint is protected by the session CSRF token above. The portable
// PHP server is bound to loopback by its launcher; additionally verify the
// actual peer address. Do not trust Host/Origin headers to decide whether the
// connection is local: proxies and browsers can legitimately alter them.
$remote = trim((string) ($_SERVER['REMOTE_ADDR'] ?? ''));
$localPeer = in_array($remote, ['127.0.0.1', '::1'], true);
if (!$localPeer && filter_var($remote, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
    // Windows/PHP can represent IPv4 localhost as an IPv4-mapped IPv6 peer.
    $packed = @inet_pton($remote);
    $localPeer = $packed !== false
        && strlen($packed) === 16
        && substr($packed, 0, 12) === hex2bin('00000000000000000000ffff')
        && substr($packed, 12) === "\x7f\x00\x00\x01";
}
if (!$localPeer) {
    http_response_code(403);
    header('Content-Type: text/html; charset=utf-8');
    exit('<!doctype html><html><head><meta charset="utf-8"><title>MedChart</title><style>body{background:#111a23;color:#e8eef4;font:16px system-ui;display:grid;place-items:center;min-height:90vh}main{max-width:540px;padding:35px;background:#1b2835;border-radius:12px}</style></head><body><main><h2>Shutdown unavailable</h2><p>This request did not originate from the local computer. Use the Stop MedChart button from the local application.</p></main></body></html>');
}

$root = dirname(__DIR__);
$flag = $root . DIRECTORY_SEPARATOR . 'data' . DIRECTORY_SEPARATOR . 'stop-request.flag';
if (!is_dir(dirname($flag)) || file_put_contents($flag, (string) time(), LOCK_EX) === false) {
    http_response_code(500);
    exit('Could not request shutdown. Please use Stop_MedChart.cmd.');
}

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store, max-age=0');
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MedChart — Shutting Down</title>
<style>
:root{color-scheme:light dark;--bg:#f3f6f8;--panel:#fff;--text:#1e2933;--muted:#536575;--border:#d7e1e7;--accent:#008f84}
@media(prefers-color-scheme:dark){:root{--bg:#101820;--panel:#1b2835;--text:#edf4f7;--muted:#b7c6cf;--border:#425364;--accent:#00c8b4}}
html[data-medchart-theme="light"]{color-scheme:light;--bg:#f3f6f8;--panel:#fff;--text:#1e2933;--muted:#536575;--border:#d7e1e7;--accent:#008f84}
html[data-medchart-theme="dark"]{color-scheme:dark;--bg:#101820;--panel:#1b2835;--text:#edf4f7;--muted:#b7c6cf;--border:#425364;--accent:#00c8b4}
*{box-sizing:border-box}body{min-height:100vh;margin:0;display:grid;place-items:center;padding:22px;background:var(--bg);color:var(--text);font:16px/1.6 system-ui,-apple-system,Segoe UI,Arial,sans-serif}
main{width:min(100%,520px);padding:42px 32px;text-align:center;background:var(--panel);border:1px solid var(--border);border-radius:14px;box-shadow:0 12px 40px #00000012}
.symbol{width:68px;height:68px;display:grid;place-items:center;margin:0 auto 18px;border:2px solid var(--accent);border-radius:50%;color:var(--accent);font-size:36px;font-weight:600}
h1{font-size:1.65rem;line-height:1.3;margin:0 0 15px}p{margin:10px 0;color:var(--muted)}strong{color:var(--text)}.hint{font-size:.92rem;margin-top:22px}
</style>
<script>
// Use the browser's preferred theme if MedChart has not stored a choice.
try {
  var theme = localStorage.getItem('medchart_theme') || localStorage.getItem('medchart-theme');
  if (theme === 'dark' || theme === 'light') document.documentElement.setAttribute('data-medchart-theme',theme);
} catch (e) {}
</script>
</head>
<body>
<main role="status">
<div class="symbol" aria-hidden="true">✓</div>
<h1>MedChart Is Shutting Down</h1>
<p>Your shutdown request has been received. The local services will close shortly.</p>
<p><strong>You can now close this browser tab.</strong></p>
<p class="hint">To use MedChart again, double-click the MedChart shortcut on your desktop.</p>
</main>
</body>
</html>
