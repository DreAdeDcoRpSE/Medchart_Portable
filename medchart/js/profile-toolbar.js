/* Profile fields only. Each field displays its own save state. */
(function(){'use strict';
 const ids=['name','dob','notes'];
 const fields=ids.map(id=>document.getElementById(id));
 const button=document.getElementById('profile-save');
 const bottomButton=document.getElementById('profile-save-bottom');
 const saveButtons=[button,bottomButton].filter(Boolean);
 if(!button||fields.some(x=>!x))return;
 let baseline=fields.map(x=>x.value),saving=false;
 const savedTimers=ids.map(()=>null);
 function cancelSavedTimer(i){if(savedTimers[i]!==null){clearTimeout(savedTimers[i]);savedTimers[i]=null;}statuses[i]?.classList.remove('profile-fading');}
 const changed=()=>fields.some((x,i)=>x.value!==baseline[i]);
 const statuses=ids.map(id=>document.getElementById('profile-status-'+id));
 function show(i,message,state){const el=statuses[i];if(!el)return;el.classList.remove('profile-fading');el.textContent=message;el.dataset.state=state||'';}
 function update(){fields.forEach((field,i)=>{cancelSavedTimer(i);if(field.value!==baseline[i])show(i,'Unsaved change — click either Save button.','dirty');else show(i,'','');});saveButtons.forEach(btn=>btn.classList.toggle('profile-dirty',changed()));}
 fields.forEach(field=>{field.addEventListener('input',update);field.addEventListener('change',update);});
 window.addEventListener('beforeunload',e=>{if(changed()&&!saving){e.preventDefault();e.returnValue='';}});
 document.addEventListener('click',e=>{if(!e.target.closest('.medchart-menu'))document.querySelectorAll('.medchart-menu[open]').forEach(x=>x.open=false);});
 window.medchartProfileSaveStarted=function(){saving=true;const snapshot=fields.map(x=>x.value);window.medchartProfileChangedAtSave=snapshot.map((value,i)=>value!==baseline[i]);return snapshot;};
 window.medchartProfileSaved=function(savedValues){saving=false;const changedAtSave=window.medchartProfileChangedAtSave||ids.map(()=>false);baseline=savedValues.slice();fields.forEach((field,i)=>{cancelSavedTimer(i);if(field.value!==baseline[i]){show(i,'Changed while saving — click Save again.','dirty');}else if(changedAtSave[i]){show(i,'Saved successfully.','saved');savedTimers[i]=setTimeout(()=>{savedTimers[i]=null;const el=statuses[i];if(field.value===baseline[i]&&el?.dataset.state==='saved'){el.classList.add('profile-fading');savedTimers[i]=setTimeout(()=>{savedTimers[i]=null;if(field.value===baseline[i]&&el.dataset.state==='saved'&&el.classList.contains('profile-fading'))show(i,'','');},550);}},3500);}else{show(i,'','');}});window.medchartProfileChangedAtSave=null;saveButtons.forEach(btn=>btn.classList.toggle('profile-dirty',changed()));};
 window.medchartProfileSaveError=function(){saving=false;window.medchartProfileChangedAtSave=null;fields.forEach((field,i)=>{if(field.value!==baseline[i])show(i,'Save failed — your change is not saved.','error');});saveButtons.forEach(btn=>btn.classList.toggle('profile-dirty',changed()));};
})();
