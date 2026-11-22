const API='api/admin.php';
const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function call(action,body,method='POST'){const r=await fetch(`${API}?action=${action}`,{method,headers:body instanceof FormData?{}:{'Content-Type':'application/json'},body:body?(body instanceof FormData?body:JSON.stringify(body)):undefined});const d=await r.json();if(!r.ok)throw new Error(d.error||'Request failed');return d}
function msg(s){$('adminMessage').textContent=s;$('adminMessage').classList.add('show');window.scrollTo({top:0,behavior:'smooth'})}
let state={};
async function load(){
 try{
  state=await call('manage',null,'GET');
  $('personDepartment').innerHTML='<option value="">Choose department</option>'+state.departments.filter(x=>Number(x.is_active)).map(x=>`<option>${esc(x.name)}</option>`).join('');
  $('departmentList').innerHTML=state.departments.map(d=>`<div class="admin-row"><div class="grow"><b>${esc(d.name)}</b><small>Ticket prefix: ${esc(d.ticket_prefix)} · ${Number(d.is_active)?'Active':'Archived'}</small></div><button class="btn btn-light" data-dept="${d.id}" data-active="${Number(d.is_active)?0:1}">${Number(d.is_active)?'Archive':'Restore'}</button></div>`).join('')||'<p>No departments yet.</p>';
  $('peopleList').innerHTML=state.users.filter(u=>u.role==='staff').map(u=>{const m=state.people[String(u.id)]||{};const photo=m.photo?`<img src="${esc(m.photo)}" alt="">`:`<div class="avatar-placeholder">${esc(u.full_name.slice(0,1).toUpperCase())}</div>`;return `<div class="admin-row" data-person="${u.id}">${photo}<div class="grow"><b>${m.kind==='doctor'?'Dr. ':''}${esc(u.full_name)}</b><small>${esc(m.specialty||'Staff')} · ${esc(m.department||'No department')} · ${esc(u.email)}</small><small>${esc(u.phone||'No phone')} · ${m.visible===false?'Hidden from patients':'Visible to patients'}</small></div><button class="btn btn-light" data-edit="${u.id}">Edit</button><button class="btn btn-light" data-photo="${u.id}">Photo</button><button class="btn btn-ghost" data-remove="${u.id}">Suspend</button></div>`}).join('')||'<p>No doctor or staff accounts yet.</p>';
  $('contactList').innerHTML=(state.contacts||[]).map((c,i)=>`<div class="admin-row"><div class="grow"><b>${esc(c.name)}</b><small>+${esc(c.phone)}</small></div><button class="btn btn-light" data-contact-edit="${i}">Edit</button><button class="btn btn-ghost" data-contact-delete="${i}">Remove</button></div>`).join('');
 }catch(e){msg(e.message+' If you just signed in, confirm that this account has admin access.');}
}
$('deptForm').addEventListener('submit',async e=>{e.preventDefault();try{await call('department',Object.fromEntries(new FormData(e.target)));e.target.reset();msg('Department added.');load()}catch(x){msg(x.message)}});
$('personForm').addEventListener('submit',async e=>{e.preventDefault();try{await call('person',Object.fromEntries(new FormData(e.target)));e.target.reset();msg('Account created and approved. The staff member must sign in with Google using that exact email.');load()}catch(x){msg(x.message)}});
$('contactForm').addEventListener('submit',async e=>{e.preventDefault();try{await call('contact',Object.fromEntries(new FormData(e.target)));e.target.reset();msg('Contact added.');load()}catch(x){msg(x.message)}});
document.addEventListener('click',async e=>{
 const b=e.target.closest('button');if(!b)return;
 try{
  if(b.dataset.dept){await call('department-status',{id:+b.dataset.dept,active:+b.dataset.active});msg('Department status updated.');await load()}
  if(b.dataset.remove){if(!confirm('Suspend this account? Existing queue and appointment history will be preserved.'))return;await call('delete-person',{id:+b.dataset.remove});msg('Account suspended.');await load()}
  if(b.dataset.edit){const id=+b.dataset.edit,u=state.users.find(x=>+x.id===id),m=state.people[String(id)]||{};const name=prompt('Full name',u.full_name);if(name===null)return;const email=prompt('Email',u.email);if(email===null)return;const phone=prompt('Phone',u.phone||'');if(phone===null)return;const kind=prompt('Type: doctor or staff',m.kind||'doctor');if(kind===null)return;const specialty=prompt('Specialty / job title',m.specialty||'');if(specialty===null)return;const department=prompt('Department',m.department||'');if(department===null)return;const whatsapp=prompt('WhatsApp number with country code',m.whatsapp||'');if(whatsapp===null)return;const visible=confirm('Show this profile in the patient doctor directory?');await call('update-person',{id,name,email,phone,kind,specialty,department,whatsapp,visible});msg('Profile updated.');await load()}
  if(b.dataset.photo){const id=+b.dataset.photo;const input=document.createElement('input');input.type='file';input.accept='image/png,image/jpeg,image/webp';input.onchange=async()=>{if(!input.files[0])return;const fd=new FormData();fd.append('id',id);fd.append('photo',input.files[0]);try{await call('upload-photo',fd);msg('Profile photo uploaded.');load()}catch(x){msg(x.message)}};input.click()}
  if(b.dataset.contactEdit!==undefined){const i=+b.dataset.contactEdit,c=state.contacts[i];const name=prompt('Contact name',c.name);if(name===null)return;const phone=prompt('WhatsApp number with country code',c.phone);if(phone===null)return;await call('update-contact',{index:i,name,phone});msg('Contact updated.');await load()}
  if(b.dataset.contactDelete!==undefined){const i=+b.dataset.contactDelete;if(!confirm('Remove this public contact?'))return;await call('delete-contact',{index:i});msg('Contact removed.');await load()}
 }catch(x){msg(x.message)}
});
$('reloadBtn').onclick=load;
$('logoutBtn').onclick=async()=>{await fetch('api/session.php',{method:'DELETE'});sessionStorage.removeItem('mq_user');location.href='index.html'};
load();
