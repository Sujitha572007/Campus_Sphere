const fs=require('fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,deleteDoc,getDoc,getDocs,collectionGroup,query,where,Timestamp,serverTimestamp,runTransaction}=require('firebase/firestore');
(async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-campus-admin',firestore:{host:'127.0.0.1',port:8085,rules:fs.readFileSync('../firestore.rules','utf8')}});
 const a=env.authenticatedContext('admin',{email:'admin@example.com'}).firestore();
 const s=env.authenticatedContext('student',{email:'student@example.com'}).firestore();
 const o=env.authenticatedContext('other',{email:'other@example.com'}).firestore();
 const n=Date.now();const data={title:'Demo',description:'Demo',clubId:'codechef',clubName:'CodeChef',category:'Technical',venue:'Demo',eventType:'Workshop',startAt:Timestamp.fromMillis(n+86400000),endAt:Timestamp.fromMillis(n+90000000),status:'scheduled',registrationOpen:true,capacity:1,registeredCount:0,eligibleYears:[2],featured:false,isDemo:true};
 let count=0;async function check(name,f){await f();count++;console.log('PASS '+name);}
 const stamp={updatedBy:'admin',updatedAt:serverTimestamp()};
 async function register(db,uid,year){return runTransaction(db,async t=>{const e=doc(db,'events/e1');const r=doc(db,`users/${uid}/registrations/e1`);const d=await t.get(e);await t.get(r);t.set(r,{eventId:'e1',studentId:uid,studentYear:year,status:'registered',registeredAt:serverTimestamp()});t.update(e,{registeredCount:d.data().registeredCount+1});});}
 try{
 await env.withSecurityRulesDisabled(async c=>{const db=c.firestore();for(const id of ['admin','student','other'])await setDoc(doc(db,'users',id),{name:id,email:id+'@example.com',role:id==='admin'?'admin':'student',createdAt:Timestamp.now()});await setDoc(doc(db,'clubs/codechef'),{name:'CodeChef',category:'Technical'});await setDoc(doc(db,'events/e1'),data);});
 await check('No self promotion',()=>assertFails(updateDoc(doc(s,'users/student'),{role:'admin'})));
 await check('Student event edit denied',()=>assertFails(updateDoc(doc(s,'events/e1'),{title:'No'})));
 await check('Admin event creation',()=>assertSucceeds(setDoc(doc(a,'events/new'),{...data,...stamp,createdBy:'admin',createdAt:serverTimestamp()})));
 await check('Student event creation denied',()=>assertFails(setDoc(doc(s,'events/no'),{...data,...stamp,createdBy:'student',createdAt:serverTimestamp()})));
 await check('Admin event edit',()=>assertSucceeds(updateDoc(doc(a,'events/e1'),{title:'Edited',...stamp})));
 await check('Admin count fabrication denied',()=>assertFails(updateDoc(doc(a,'events/e1'),{registeredCount:10,...stamp})));
 await check('Ineligible student denied',()=>assertFails(register(s,'student',1)));
 await check('Atomic registration succeeds',()=>assertSucceeds(register(s,'student',2)));
 await check('Duplicate denied',()=>assertFails(register(s,'student',2)));
 await check('Capacity protected',()=>assertFails(register(o,'other',2)));
 await check('Other student registration private',()=>assertFails(getDoc(doc(o,'users/student/registrations/e1'))));
 await check('Admin sees registrations',()=>assertSucceeds(getDocs(query(collectionGroup(a,'registrations'),where('eventId','==','e1')))));
 await check('Admin reads student profile',()=>assertSucceeds(getDoc(doc(a,'users/student'))));
 await check('Registered event deletion denied',()=>assertFails(deleteDoc(doc(a,'events/e1'))));
 await check('Admin completion',()=>assertSucceeds(updateDoc(doc(a,'events/e1'),{status:'completed',registrationOpen:false,completedAt:serverTimestamp(),...stamp})));
 await check('Admin cancellation',()=>assertSucceeds(updateDoc(doc(a,'events/e1'),{status:'cancelled',registrationOpen:false,...stamp})));
 await check('History retained',async()=>{if(!(await getDoc(doc(s,'users/student/registrations/e1'))).exists())throw Error('Missing registration');});
 await check('Zero registration deletion',()=>assertSucceeds(deleteDoc(doc(a,'events/new'))));
 await check('Admin request allowed',()=>assertSucceeds(setDoc(doc(s,'admin_requests/student'),{studentId:'student',email:'student@example.com',name:'Student',status:'pending',requestedAt:serverTimestamp()})));
 await check('Request self approval denied',()=>assertFails(updateDoc(doc(s,'admin_requests/student'),{status:'approved'})));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/admin'),{role:'student'}));
 await check('Revoked admin denied',()=>assertFails(updateDoc(doc(a,'events/e1'),{title:'No',...stamp})));
 console.log(count+' security checks passed');
 }finally{await env.cleanup();}
})().catch(e=>{console.error(e);process.exit(1)});
