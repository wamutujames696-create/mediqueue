<?php
require_once __DIR__ . '/../db.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_set_cookie_params(['httponly' => true, 'secure' => !empty($_SERVER['HTTPS']), 'samesite' => 'Lax']);
    session_start();
}
function respond(int $status, array $data): never {
    http_response_code($status);
    echo json_encode($data);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') respond(405, ['error' => 'Method not allowed.']);
$input = json_decode(file_get_contents('php://input'), true) ?: [];
$credential = $input['credential'] ?? '';
if (!is_string($credential) || $credential === '') respond(400, ['error' => 'Google credential is missing.']);
if (GOOGLE_CLIENT_ID === 'PASTE_YOUR_GOOGLE_WEB_CLIENT_ID_HERE') respond(503, ['error' => 'Google Sign-In is not configured yet. Add your Google Web Client ID in config.php.']);

// Verify the ID token with Google's tokeninfo endpoint, then validate its audience and identity.
$ch = curl_init('https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($credential));
curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10]);
$body = curl_exec($ch);
$http = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
$claims = is_string($body) ? json_decode($body, true) : null;
if ($http !== 200 || !is_array($claims) || !hash_equals(GOOGLE_CLIENT_ID, (string)($claims['aud'] ?? '')) || (string)($claims['email_verified'] ?? '') !== 'true' || empty($claims['sub']) || empty($claims['email'])) {
    respond(401, ['error' => 'Google could not verify this account. Please try again.']);
}
try {
    $pdo = db();
    $stmt = $pdo->prepare('SELECT id, full_name, email, role, status FROM users WHERE google_sub = ? OR email = ? LIMIT 1');
    $stmt->execute([(string)$claims['sub'], strtolower((string)$claims['email'])]);
    $user = $stmt->fetch();
    if ($user) {
        if (empty($user['google_sub'])) {
            $link = $pdo->prepare('UPDATE users SET google_sub = ?, full_name = COALESCE(NULLIF(full_name, ""), ?) WHERE id = ?');
            $link->execute([(string)$claims['sub'], (string)($claims['name'] ?? ''), $user['id']]);
        }
    } else {
        $name = trim((string)($claims['name'] ?? '')) ?: 'Google User';
        $email = strtolower((string)$claims['email']);
        $insert = $pdo->prepare("INSERT INTO users (google_sub, full_name, email, role, status, auth_provider) VALUES (?, ?, ?, 'patient', 'Active', 'google')");
        $insert->execute([(string)$claims['sub'], $name, $email]);
        $user = ['id' => (int)$pdo->lastInsertId(), 'full_name' => $name, 'email' => $email, 'role' => 'patient', 'status' => 'Active'];
    }
    if (($user['role'] ?? '') === 'staff' && ($user['status'] ?? '') !== 'Approved') respond(403, ['error' => 'Your staff account is awaiting Admin approval.']);
    session_regenerate_id(true);
    $_SESSION['mq_user'] = ['id' => (int)$user['id'], 'name' => $user['full_name'], 'email' => $user['email'], 'role' => $user['role']];
    respond(200, ['user' => $_SESSION['mq_user']]);
} catch (Throwable $e) {
    error_log('MediQueue Google sign-in: ' . $e->getMessage());
    respond(500, ['error' => 'Could not save your account. Check the database setup and try again.']);
}
