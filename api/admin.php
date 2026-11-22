<?php
require_once __DIR__ . '/../db.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_set_cookie_params(['httponly'=>true,'secure'=>!empty($_SERVER['HTTPS']),'samesite'=>'Lax']);
    session_start();
}
function out($code,$data){http_response_code($code);echo json_encode($data);exit;}
function who(){return $_SESSION['mq_user'] ?? null;}
function require_admin(){ $u=who(); if(!$u || ($u['role']??'')!=='admin') out(403,['error'=>'Administrator access required.']); return $u; }
function meta_file(){return __DIR__.'/../storage/people.json';}
function meta_read(){ $p=meta_file();$d=is_file($p)?json_decode(file_get_contents($p),true):null;return is_array($d)?$d:['people'=>[],'contacts'=>[]];}
function meta_write($d){if(file_put_contents(meta_file(),json_encode($d,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),LOCK_EX)===false)out(500,['error'=>'Could not save profile details. Check storage folder permissions.']);}
function clean($v,$max=180){return mb_substr(trim((string)$v),0,$max);}
$method=$_SERVER['REQUEST_METHOD'];
$action=$_GET['action']??'';
try {
 $pdo=db();
 if($method==='GET' && $action==='public'){
   $d=meta_read();
   $rows=$pdo->query("SELECT id,full_name,email,phone FROM users WHERE role='staff' AND status='Approved' ORDER BY full_name")->fetchAll();
   $doctors=[];
   foreach($rows as $r){$m=$d['people'][(string)$r['id']]??[];if(($m['kind']??'doctor')==='doctor' && !empty($m['visible']))$doctors[]=['id'=>(int)$r['id'],'title'=>$m['title']??'Dr.','name'=>$r['full_name'],'specialty'=>$m['specialty']??'Medical practitioner','department'=>$m['department']??'','phone'=>$r['phone']??'','whatsapp'=>$m['whatsapp']??'','photo'=>$m['photo']??''];}
   $deps=$pdo->query("SELECT id,name FROM departments WHERE is_active=1 ORDER BY name")->fetchAll();
   out(200,['doctors'=>$doctors,'departments'=>$deps,'contacts'=>$d['contacts']??[]]);
 }
 if($method==='POST' && $action==='claim-admin'){
   $u=who(); if(!$u)out(401,['error'=>'Sign in with Google first, then return to this page.']);
   $input=json_decode(file_get_contents('php://input'),true)?:[];
   if(!hash_equals('WAMUTU',(string)($input['code']??'')))out(400,['error'=>'The administrator setup code is incorrect.']);
   $count=(int)$pdo->query("SELECT COUNT(*) FROM users WHERE role='admin'")->fetchColumn();
   if($count>0)out(409,['error'=>'An administrator is already set up. Ask the existing administrator to create your account.']);
   $st=$pdo->prepare("UPDATE users SET role='admin',status='Active' WHERE id=?");
   $st->execute([(int)$u['id']]);
   $_SESSION['mq_user']['role']='admin';
   out(200,['ok'=>true,'message'=>'This Google account is now the MediQueue administrator.']);
 }
 require_admin();
 if($method==='GET' && $action==='manage'){
   $d=meta_read();
   $users=$pdo->query("SELECT id,full_name,email,phone,role,status FROM users WHERE role IN ('staff','admin') ORDER BY full_name")->fetchAll();
   $deps=$pdo->query("SELECT id,name,ticket_prefix,is_active FROM departments ORDER BY name")->fetchAll();
   out(200,['users'=>$users,'departments'=>$deps,'people'=>$d['people'],'contacts'=>$d['contacts']??[]]);
 }
 if($method==='POST' && $action==='department'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$name=clean($in['name']??'',120);$prefix=strtoupper(preg_replace('/[^A-Z]/','',clean($in['prefix']??'',5)));
   if($name===''||$prefix==='')out(400,['error'=>'Department name and ticket prefix are required.']);
   $st=$pdo->prepare('INSERT INTO departments (name,ticket_prefix,is_active) VALUES (?,?,1)');$st->execute([$name,substr($prefix,0,5)]);
   out(200,['ok'=>true,'id'=>(int)$pdo->lastInsertId()]);
 }
 if($method==='POST' && $action==='person'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];
   $name=clean($in['name']??'',160);$email=strtolower(clean($in['email']??'',190));$phone=clean($in['phone']??'',30);
   $kind=($in['kind']??'doctor')==='staff'?'staff':'doctor';
   $title=$kind==='doctor'?'Dr.':clean($in['title']??'Staff',30);
   if($name===''||!filter_var($email,FILTER_VALIDATE_EMAIL))out(400,['error'=>'Enter a full name and valid email address.']);
   $existing=$pdo->prepare("SELECT id,role FROM users WHERE email=? LIMIT 1");$existing->execute([$email]);$found=$existing->fetch();
   if($found){
     if($found['role']==='admin')out(409,['error'=>'That email already belongs to an administrator.']);
     $id=(int)$found['id'];
     $up=$pdo->prepare("UPDATE users SET full_name=?,phone=?,role='staff',status='Approved' WHERE id=?");$up->execute([$name,$phone,$id]);
   }else{
     $st=$pdo->prepare("INSERT INTO users (full_name,email,phone,role,status,auth_provider) VALUES (?,?,?,'staff','Approved','google')");
     $st->execute([$name,$email,$phone]);$id=(int)$pdo->lastInsertId();
   }
   $d=meta_read();$d['people'][(string)$id]=['kind'=>$kind,'title'=>$title,'specialty'=>clean($in['specialty']??'Medical practitioner',120),'department'=>clean($in['department']??'',120),'whatsapp'=>preg_replace('/\D/','',(string)($in['whatsapp']??'')),'photo'=>'','visible'=>true];
   meta_write($d);out(200,['ok'=>true,'id'=>$id]);
 }
 if($method==='POST' && $action==='update-person'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$id=(int)($in['id']??0);
   $st=$pdo->prepare("UPDATE users SET full_name=?,email=?,phone=? WHERE id=? AND role='staff'");
   $st->execute([clean($in['name']??'',160),strtolower(clean($in['email']??'',190)),clean($in['phone']??'',30),$id]);
   if(!$st->rowCount() && !$pdo->query("SELECT id FROM users WHERE id=$id AND role='staff'")->fetch())out(404,['error'=>'Staff member not found.']);
   $d=meta_read();$old=$d['people'][(string)$id]??[];
   $d['people'][(string)$id]=array_merge($old,['kind'=>($in['kind']??($old['kind']??'doctor')),'title'=>($in['kind']??'doctor')==='doctor'?'Dr.':clean($in['title']??'Staff',30),'specialty'=>clean($in['specialty']??'',120),'department'=>clean($in['department']??'',120),'whatsapp'=>preg_replace('/\D/','',(string)($in['whatsapp']??'')),'visible'=>!empty($in['visible'])]);
   meta_write($d);out(200,['ok'=>true]);
 }
 if($method==='POST' && $action==='delete-person'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$id=(int)($in['id']??0);
   $st=$pdo->prepare("UPDATE users SET status='Suspended' WHERE id=? AND role='staff'");$st->execute([$id]);
   $d=meta_read();unset($d['people'][(string)$id]);meta_write($d);out(200,['ok'=>true,'message'=>'Account suspended; historical records are preserved.']);
 }
 if($method==='POST' && $action==='department-status'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$id=(int)($in['id']??0);$active=!empty($in['active'])?1:0;
   $st=$pdo->prepare('UPDATE departments SET is_active=? WHERE id=?');$st->execute([$active,$id]);out(200,['ok'=>true]);
 }
 if($method==='POST' && $action==='contact'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$name=clean($in['name']??'',120);$phone=preg_replace('/\D/','',(string)($in['phone']??''));
   if($name===''||strlen($phone)<9)out(400,['error'=>'Enter a contact name and phone number with country code.']);
   $d=meta_read();$d['contacts'][]=['name'=>$name,'phone'=>$phone];meta_write($d);out(200,['ok'=>true]);
 }
 if($method==='POST' && $action==='update-contact'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$idx=(int)($in['index']??-1);$d=meta_read();
   if(!isset($d['contacts'][$idx]))out(404,['error'=>'Contact not found.']);
   $name=clean($in['name']??'',120);$phone=preg_replace('/\D/','',(string)($in['phone']??''));
   if($name===''||strlen($phone)<9)out(400,['error'=>'Enter a contact name and phone number with country code.']);
   $d['contacts'][$idx]=['name'=>$name,'phone'=>$phone];meta_write($d);out(200,['ok'=>true]);
 }
 if($method==='POST' && $action==='delete-contact'){
   $in=json_decode(file_get_contents('php://input'),true)?:[];$idx=(int)($in['index']??-1);$d=meta_read();
   if(!isset($d['contacts'][$idx]))out(404,['error'=>'Contact not found.']);
   array_splice($d['contacts'],$idx,1);meta_write($d);out(200,['ok'=>true]);
 }
 if($method==='POST' && $action==='upload-photo'){
   $id=(int)($_POST['id']??0);if($id<1||empty($_FILES['photo']))out(400,['error'=>'Choose a profile image.']);
   $f=$_FILES['photo'];if($f['error']!==UPLOAD_ERR_OK||$f['size']>3*1024*1024)out(400,['error'=>'Image upload failed or exceeds 3 MB.']);
   $mime=(new finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);$ext=['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'][$mime]??null;if(!$ext)out(400,['error'=>'Use JPG, PNG or WebP images only.']);
   $dir=__DIR__.'/../uploads/profiles';if(!is_dir($dir))mkdir($dir,0755,true);$file='doctor-'.$id.'-'.bin2hex(random_bytes(5)).'.'.$ext;
   if(!move_uploaded_file($f['tmp_name'],$dir.'/'.$file))out(500,['error'=>'Could not save the image.']);
   $d=meta_read();$d['people'][(string)$id]['photo']='uploads/profiles/'.$file;meta_write($d);out(200,['ok'=>true,'photo'=>'uploads/profiles/'.$file]);
 }
 out(404,['error'=>'Unknown action.']);
} catch(Throwable $e){error_log('MediQueue admin API: '.$e->getMessage());out(500,['error'=>'Request failed. Check the database connection and ensure the original database schema is installed.']);}
