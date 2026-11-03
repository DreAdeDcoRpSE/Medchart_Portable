<?php
/** Local-only browser activity marker for the portable launcher. */
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') { http_response_code(405); exit; }
$ip = $_SERVER['REMOTE_ADDR'] ?? '';
if ($ip !== '127.0.0.1' && $ip !== '::1') { http_response_code(403); exit; }
$host = $_SERVER['HTTP_HOST'] ?? '';
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '' && !hash_equals('http://' . $host, $origin)) { http_response_code(403); exit; }
if (($_SERVER['HTTP_X_MEDCHART_HEARTBEAT'] ?? '') !== '1') { http_response_code(403); exit; }
$id = (string)($_POST['tab'] ?? '');
if (!preg_match('/^[a-f0-9]{32}$/D', $id)) { http_response_code(400); exit; }
$root = dirname(__DIR__);
$instance = $root . '/data/instance-id.txt';
if (!is_file($instance)) { http_response_code(503); exit; }
$run = trim((string)file_get_contents($instance));
if (!preg_match('/^[a-f0-9]{32}$/D', $run)) { http_response_code(503); exit; }
$dir = $root . '/data/heartbeats';
if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) { http_response_code(500); exit; }
$path = $dir . '/' . $run . '-' . $id . '.beat';
if (file_put_contents($path, (string)time(), LOCK_EX) === false) { http_response_code(500); exit; }
header('Cache-Control: no-store');
http_response_code(204);
