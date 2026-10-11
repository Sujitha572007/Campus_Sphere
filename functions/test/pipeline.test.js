'use strict';
const test=require('node:test'); const assert=require('node:assert/strict'); const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');
function harness() {
  const rows=new Map();let sends=0,fail=false;
  const ref=p=>({path:p,id:p.split('/').at(-1),parent:{parent:{id:p.split('/').at(-3)}},collection:n=>({doc:id=>ref(`${p}/${n}/${id}`)}),get:async()=>snap(p),update:async v=>{rows.set(p,{...rows.get(p),...v});}});
  const snap=p=>({exists:rows.has(p),data:()=>rows.get(p),ref:ref(p),id:p.split('/').at(-1)});
  const apply=[];
  const writer=()=>({get:async r=>snap(r.path),create:(r,d)=>{if(rows.has(r.path))throw Error('duplicate');rows.set(r.path,d);},update:(r,d)=>rows.set(r.path,{...rows.get(r.path),...d}),set:(r,d)=>rows.set(r.path,d),commit:async()=>{}});
  const query=(name,field,op,value)=>({orderBy(){return this;},limit(){return this;},startAfter(){return this;},get:async()=>{const docs=[...rows.keys()].filter(p=>p.split('/').at(-2)===name).map(snap).filter(s=>op==='in'?value.includes(s.data()[field]):s.data()[field]===value);return {docs,empty:!docs.length,size:docs.length};}});
  const db={collection:n=>({doc:id=>ref(`${n}/${id}`),where:(f,o,v)=>query(n,f,o,v)}),collectionGroup:n=>({where:(f,o,v)=>query(n,f,o,v)}),batch:writer,runTransaction:async fn=>fn(writer())};
  const adminAuth={getUser:async uid=>({email:`${uid}@example.com`,disabled:false})};
  const mocks={
    'firebase-admin/app':{initializeApp(){}},
    'firebase-admin/firestore':{getFirestore:()=>db,FieldValue:{serverTimestamp:()=>new Date(),delete:()=>null},Timestamp:{fromMillis:ms=>({toMillis:()=>ms})}},
    'firebase-admin/auth':{getAuth:()=>adminAuth},
    'firebase-functions/v2/firestore':{onDocumentCreated:(_,fn)=>fn,onDocumentUpdated:(_,fn)=>fn},
    'firebase-functions/v2/scheduler':{onSchedule:(_,fn)=>fn},
    'firebase-functions/params':{defineSecret:()=>({value:()=> 'fake-test-secret'})},
    'firebase-functions/v2':{setGlobalOptions(){}},
    'firebase-functions/logger':{error(){}},
    nodemailer:{createTransport:()=>({sendMail:async mail=>{sends++;if(fail)throw Error('SMTP unavailable');assert.equal(mail.from,'CampusSphere <achyutha0506@gmail.com>');assert.equal(mail.to,'s@example.com');},close(){}})},
    './logic':require('../logic'),
  };
  const exports={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../index.js'),'utf8'),{require:n=>mocks[n],exports,console,Date,Promise,Error});
  rows.set('users/s',{name:'Student',role:'student'});rows.set('events/e',{title:'Workshop',clubName:'Club',venue:'A108'});
  const registration={params:{studentId:'s',eventId:'e'},data:{data:()=>({status:'registered'})}};
  return {rows,exports,ref,registration,get sends(){return sends;},set fail(v){fail=v;}};
}
test('registration retry creates one notification/job; delivery retry does not resend sent job',async()=>{const h=harness();await h.exports.registrationCreated(h.registration);await h.exports.registrationCreated(h.registration);assert.equal([...h.rows.keys()].filter(k=>k.includes('/notifications/')).length,1);const jobs=[...h.rows.keys()].filter(k=>k.startsWith('mail_jobs/'));assert.equal(jobs.length,1);const event={data:{ref:h.ref(jobs[0])}};await h.exports.sendRegistrationEmail(event);await h.exports.sendRegistrationEmail(event);assert.equal(h.sends,1);assert.equal(h.rows.get('users/s/email_receipts/e').status,'sent');});
test('opt out prevents notification and email',async()=>{const h=harness();h.rows.set('users/s/preferences/settings',{inAppNotifications:false,emailConfirmations:false});await h.exports.registrationCreated(h.registration);assert.equal([...h.rows.keys()].filter(k=>k.includes('/notifications/')).length,0);assert.equal(h.rows.get('users/s/email_receipts/e').status,'skipped');await h.exports.retryRegistrationEmails();assert.equal(h.sends,0);});
test('delivery failure preserves registration; retries stop after five attempts',async()=>{const h=harness();h.rows.set('users/s/registrations/e',{status:'registered'});await h.exports.registrationCreated(h.registration);h.fail=true;for(let i=0;i<6;i++)await h.exports.retryRegistrationEmails();assert.equal(h.sends,5);assert.equal(h.rows.get('users/s/email_receipts/e').status,'failed');assert.equal(h.rows.get('users/s/registrations/e').status,'registered');});
test('attendance trigger retry is idempotent; count updates do not notify',async()=>{const h=harness();const e={params:{studentId:'s',eventId:'e'}};await h.exports.attendanceCreated(e);await h.exports.attendanceCreated(e);assert.equal([...h.rows.keys()].filter(k=>k.includes('/notifications/')).length,1);await h.exports.eventUpdated({params:{eventId:'e'},data:{before:{data:()=>({registeredCount:1})},after:{data:()=>({registeredCount:2})}}});assert.equal([...h.rows.keys()].filter(k=>k.includes('/notifications/')).length,1);});
