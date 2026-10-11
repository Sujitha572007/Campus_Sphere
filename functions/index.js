'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {onDocumentCreated,onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret} = require('firebase-functions/params');
const {setGlobalOptions} = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const nodemailer = require('nodemailer');
const {stableId,changedEvent,confirmationText} = require('./logic');
initializeApp();
setGlobalOptions({region:'asia-south1',maxInstances:3});
const db = getFirestore();
const gmailPassword = defineSecret('GMAIL_APP_PASSWORD');
const sender = 'achyutha0506@gmail.com';
const opts = document => ({document,retry:true});
const userRef = uid => db.collection('users').doc(uid);
async function preferences(uid) { return (await userRef(uid).collection('preferences').doc('settings').get()).data() || {}; }
async function notify(uid, id, data) {
  if ((await preferences(uid)).inAppNotifications === false) return;
  const ref = userRef(uid).collection('notifications').doc(id);
  await db.runTransaction(async tx => {
    if ((await tx.get(ref)).exists) return;
    tx.create(ref,{...data,read:false,createdAt:FieldValue.serverTimestamp()});
  });
}
exports.registrationCreated = onDocumentCreated(opts('users/{studentId}/registrations/{eventId}'), async event => {
  const {studentId,eventId} = event.params;
  if (event.data?.data().status !== 'registered') return;
  const [savedEvent,profile,prefs] = await Promise.all([db.collection('events').doc(eventId).get(),userRef(studentId).get(),preferences(studentId)]);
  if (!savedEvent.exists || !profile.exists) return;
  const data=savedEvent.data();
  await notify(studentId, `registration-${eventId}`, {type:'registration',eventId,title:'Registration confirmed',body:`You are successfully registered for ${data.title}. Your QR ticket is in My Registered Events.`});
  const job = db.collection('mail_jobs').doc(stableId(studentId,eventId));
  const receipt = userRef(studentId).collection('email_receipts').doc(eventId);
  const account = await getAuth().getUser(studentId);
  const allowed = prefs.emailConfirmations !== false && account.email && !account.disabled;
  await db.runTransaction(async tx => {
    if ((await tx.get(job)).exists) return;
    tx.create(job,{studentId,eventId,status:allowed?'pending':'skipped',attempts:0,createdAt:FieldValue.serverTimestamp(),to:account.email || '',subject:`CampusSphere registration: ${String(data.title).replace(/[\r\n]/g,' ').slice(0,150)}`,text:confirmationText(profile.data().name,data)});
    tx.set(receipt,{status:allowed?'queued':'skipped',updatedAt:FieldValue.serverTimestamp()});
  });
});
exports.attendanceCreated = onDocumentCreated(opts('users/{studentId}/checkins/{eventId}'),async event => {
  const {studentId,eventId}=event.params;
  const saved=await db.collection('events').doc(eventId).get();
  await notify(studentId,`checkin-${eventId}`,{type:'checkin',eventId,title:'Attendance recorded',body:`You have checked in for ${saved.data()?.title || 'your event'}.`});
});
exports.eventUpdated = onDocumentUpdated(opts('events/{eventId}'),async event => {
  const before=event.data.before.data(), after=event.data.after.data();
  if (!changedEvent(before,after)) return; // Registration count changes do not fan out.
  const eventId=event.params.eventId;
  const regs = db.collectionGroup('registrations').where('eventId','==',eventId);
  let last;
  while (true) {
    let query=regs.orderBy('__name__').limit(200);
    if(last) query=query.startAfter(last);
    const page=await query.get();
    if(page.empty) break;
    for(const r of page.docs) {
      const uid=r.data().studentId;
      if(r.data().status !== 'registered' || r.ref.parent.parent?.id !== uid) continue;
      await notify(uid,stableId('event-update',event.id),{type:'event',eventId,title:after.status==='cancelled'?'Event cancelled':after.status==='completed'?'Event completed':'Event details updated',body:`${after.title}: ${after.status==='cancelled'?'This event has been cancelled.':'Open the event in My Registered Events to see the latest details.'}`});
    }
    last=page.docs.at(-1);
    if(page.size<200) break;
  }
});
// Atomic lease suppresses ordinary retries/concurrent deliveries. SMTP cannot
// guarantee exactly-once delivery if a process exits after Gmail accepts a mail.
async function deliver(ref) {
  const claimed=await db.runTransaction(async tx => {
    const snapshot=await tx.get(ref),d=snapshot.data();
    if(!d || ['sent','skipped','failed'].includes(d.status)) return null;
    if(d.leaseUntil?.toMillis()>Date.now()) throw new Error('Mail delivery lease is active');
    if((d.attempts || 0)>=5) {
      tx.update(ref,{status:'failed'});
      tx.set(userRef(d.studentId).collection('email_receipts').doc(d.eventId),{status:'failed',updatedAt:FieldValue.serverTimestamp()});
      return null;
    }
    tx.update(ref,{status:'sending',attempts:(d.attempts || 0)+1,leaseUntil:Timestamp.fromMillis(Date.now()+5*60*1000)});
    return d;
  });
  if(!claimed) return;
  const receipt=userRef(claimed.studentId).collection('email_receipts').doc(claimed.eventId);
  try {
    // Respect an opt-out or disabled account made before delivery.
    const [prefs,account]=await Promise.all([preferences(claimed.studentId),getAuth().getUser(claimed.studentId)]);
    if(prefs.emailConfirmations===false || account.disabled || account.email!==claimed.to) {
      const b=db.batch();b.update(ref,{status:'skipped',leaseUntil:FieldValue.delete()});b.set(receipt,{status:'skipped',updatedAt:FieldValue.serverTimestamp()});await b.commit();return;
    }
    const transport=nodemailer.createTransport({service:'gmail',auth:{user:sender,pass:gmailPassword.value()},connectionTimeout:20000,socketTimeout:30000});
    try {
      await transport.sendMail({from:`CampusSphere <${sender}>`,to:claimed.to,subject:claimed.subject,text:claimed.text,messageId:`<${ref.id}@campussphere.local>`});
    } finally { transport.close(); }
    const batch=db.batch();
    batch.update(ref,{status:'sent',sentAt:FieldValue.serverTimestamp(),leaseUntil:FieldValue.delete()});
    batch.set(receipt,{status:'sent',updatedAt:FieldValue.serverTimestamp()});
    await batch.commit();
  } catch(error) {
    await ref.update({status:'pending',leaseUntil:FieldValue.delete()});
    logger.error('Registration email failed', {jobId:ref.id,code:error.code || 'DELIVERY_ERROR'});
    throw new Error('Registration email delivery failed');
  }
}
exports.sendRegistrationEmail=onDocumentCreated({...opts('mail_jobs/{jobId}'),secrets:[gmailPassword],timeoutSeconds:120},event=>deliver(event.data.ref));
exports.retryRegistrationEmails=onSchedule({schedule:'every 10 minutes',secrets:[gmailPassword],timeoutSeconds:300},async()=> {
  const jobs=await db.collection('mail_jobs').where('status','in',['pending','sending']).limit(20).get();
  for(const job of jobs.docs) {
    try { await deliver(job.ref); } catch(_) { /* Next invocation retries; details logged by deliver. */ }
  }
});
