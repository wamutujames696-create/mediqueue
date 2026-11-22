<?php
require_once __DIR__ . '/../config.php';
header('Content-Type: application/javascript; charset=utf-8');
header('Cache-Control: no-store');
echo 'window.MEDI_QUEUE_GOOGLE_CLIENT_ID = ' . json_encode(GOOGLE_CLIENT_ID) . ';';
