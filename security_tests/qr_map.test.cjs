const fs=require('fs');const {initializeTestEnvironment,assertSucceeds:ok,assertFails:no}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,deleteDoc,Timestamp,serverTimestamp}=require('firebase/firestore');
(async()=>{const env=await initializeTestEnvironment({projectId:'demo-campus-admin',firestore:{host:'127.0.0.1',port:8085,rules:fs.readFileSync('../firestore.rules','utf8')}});
const a=env.authenticatedContext('admin').firestore(),s=env.authenticatedContext('student').firestore(),o=env.authenticatedContext('other').firestore();const token='a'.repeat(43);let count=0;
async function check(name,p){await p;console.log('PASS '+name);count++;}
const payload={eventId:'live',studentId:'student',checkedInBy:'admin',checkedInAt:serverTimestamp()};
try{await env.withSecurityRulesDisabled(async c=>{const db=c.firestore();for(const id of ['admin','student','other'])await setDoc(doc(db,'users/'+id),{role:id==='admin'?'admin':'student'});
for(const [id,status,start,end] of [['live','scheduled',-60000,3600000],['future','scheduled',86400000,90000000],['cancel','cancelled',-60000,3600000],['past','completed',-3600000,-1000]]){await setDoc(doc(db,'events/'+id),{status,startAt:Timestamp.fromMillis(Date.now()+start),endAt:Timestamp.fromMillis(Date.now()+end)});await setDoc(doc(db,`users/student/registrations/${id}`),{eventId:id,studentId:'student',studentYear:2,status:'registered',registeredAt:Timestamp.now()});}});
await check('Owner backfill',ok(updateDoc(doc(s,'users/student/registrations/live'),{ticketToken:token})));
await check('No token rotation',no(updateDoc(doc(s,'users/student/registrations/live'),{ticketToken:'b'.repeat(43)})));
await check('Private ticket',no(getDoc(doc(o,'users/student/registrations/live'))));
await check('Cannot change year',no(updateDoc(doc(s,'users/student/registrations/future'),{ticketToken:token,studentYear:4})));
await check('Malformed token denied',no(updateDoc(doc(s,'users/student/registrations/future'),{ticketToken:'short'})));
await check('Student attendance denied',no(setDoc(doc(s,'users/student/checkins/live'),{...payload,checkedInBy:'student'})));
await check('Admin attendance',ok(setDoc(doc(a,'users/student/checkins/live'),payload)));
await check('No duplicate attendance',no(setDoc(doc(a,'users/student/checkins/live'),payload)));
await check('Owner attendance read',ok(getDoc(doc(s,'users/student/checkins/live'))));
await check('Attendance private',no(getDoc(doc(o,'users/student/checkins/live'))));
await check('No attendance deletion',no(deleteDoc(doc(a,'users/student/checkins/live'))));
for(const id of ['future','cancel','past']){await updateDoc(doc(s,`users/student/registrations/${id}`),{ticketToken:token});await check(id+' checkin denied',no(setDoc(doc(a,`users/student/checkins/${id}`),{...payload,eventId:id})));}
await check('Unregistered denied',no(setDoc(doc(a,'users/other/checkins/live'),{...payload,studentId:'other'})));
const place={name:'A Block',latitude:16.56,longitude:81.52,verified:true,updatedAt:serverTimestamp()};
await check('Admin map save',ok(setDoc(doc(a,'campus_places/a'),place)));
await check('Student map read',ok(getDoc(doc(s,'campus_places/a'))));
await check('Student map edit denied',no(updateDoc(doc(s,'campus_places/a'),{...place,name:'Changed'})));
await check('Bad coordinates denied',no(setDoc(doc(a,'campus_places/b'),{...place,latitude:100})));
console.log('PASS '+count+' QR/map checks');}finally{await env.cleanup();}})().catch(e=>{console.error(e);process.exitCode=1;});
