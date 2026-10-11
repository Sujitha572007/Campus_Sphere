const fs=require('fs');const {initializeTestEnvironment,assertSucceeds:ok,assertFails:no}=require('@firebase/rules-unit-testing');const {doc,setDoc,getDoc,updateDoc,runTransaction,Timestamp,serverTimestamp,writeBatch}=require('firebase/firestore');
(async()=>{const env=await initializeTestEnvironment({projectId:'demo-campus-admin',firestore:{host:'127.0.0.1',port:8085,rules:fs.readFileSync('../firestore.rules','utf8')}});let count=0;async function check(n,p){await p;count++;console.log('PASS '+n);}const a=env.authenticatedContext('admin').firestore(),s=env.authenticatedContext('student').firestore();try{
const e={title:'Demo',description:'Demo',clubId:'c',clubName:'Club',category:'Technical',venue:'A108',eventType:'Workshop',startAt:Timestamp.fromMillis(Date.now()+1800000),endAt:Timestamp.fromMillis(Date.now()+3600000),status:'scheduled',registrationOpen:true,capacity:10,registeredCount:0,eligibleYears:[2],featured:false,isDemo:true};
await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();await setDoc(doc(d,'users/admin'),{role:'admin'});await setDoc(doc(d,'users/student'),{role:'student'});await setDoc(doc(d,'events/e'),e);});
const notif={eventId:'e',type:'registration',title:'Registration confirmed',body:'You are successfully registered for Demo. Your QR ticket is in My Registered Events.',read:false,createdAt:serverTimestamp()};
await check('Cannot fabricate registration confirmation',no(setDoc(doc(s,'users/student/notifications/registration-e'),notif)));
await check('Registration + count + notification atomically succeed',ok(runTransaction(s,async t=>{const ev=doc(s,'events/e'),r=doc(s,'users/student/registrations/e');const d=await t.get(ev);await t.get(r);await t.get(doc(s,'users/student/preferences/settings'));t.set(r,{eventId:'e',studentId:'student',studentYear:2,status:'registered',registeredAt:serverTimestamp(),ticketToken:'a'.repeat(43)});t.update(ev,{registeredCount:d.data().registeredCount+1});t.set(doc(s,'users/student/notifications/registration-e'),notif);} )));
await check('Student can read immediate notification',ok(getDoc(doc(s,'users/student/notifications/registration-e'))));
await check('No duplicate or forged notification replay',no(setDoc(doc(s,'users/student/notifications/registration-e'),notif)));
await check('Admin can read missing preferences',ok(getDoc(doc(a,'users/student/preferences/settings'))));
const attNotif={eventId:'e',type:'checkin',title:'Attendance recorded',body:'You have checked in for Demo.',read:false,createdAt:serverTimestamp()};
await check('Admin cannot send fake attendance confirmation',no(setDoc(doc(a,'users/student/notifications/checkin-e'),attNotif)));
const b=writeBatch(a);b.set(doc(a,'users/student/checkins/e'),{eventId:'e',studentId:'student',checkedInBy:'admin',checkedInAt:serverTimestamp()});b.set(doc(a,'users/student/notifications/checkin-e'),attNotif);
await check('Attendance and notification atomically saved',ok(b.commit()));
await check('No duplicate attendance',no(setDoc(doc(a,'users/student/checkins/e'),{eventId:'e',studentId:'student',checkedInBy:'admin',checkedInAt:serverTimestamp()})));
await check('Student sees attendance confirmation',ok(getDoc(doc(s,'users/student/notifications/checkin-e'))));
console.log(count+' immediate confirmation checks passed');}finally{await env.cleanup();}})().catch(e=>{console.error(e);process.exitCode=1;});
