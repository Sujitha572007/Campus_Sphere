'use strict';
const {createHash} = require('node:crypto');
function stableId(...parts) { return createHash('sha256').update(JSON.stringify(parts)).digest('hex'); }
function changedEvent(before, after) {
  const fields = ['title','description','venue','startAt','endAt','registrationDeadline','status','registrationOpen'];
  const normalize = v => v?.toMillis ? v.toMillis() : v ?? null;
  return fields.some(k => JSON.stringify(normalize(before[k])) !== JSON.stringify(normalize(after[k])));
}
function indiaTime(value) {
  if (!value?.toDate) return 'To be announced';
  return new Intl.DateTimeFormat('en-IN', {timeZone:'Asia/Kolkata',dateStyle:'medium',timeStyle:'short'}).format(value.toDate())+' IST';
}
function confirmationText(name, event) {
  return `Hello ${name || 'Student'},\n\nYou are successfully registered for ${event.title || 'your event'}!\n\nClub: ${event.clubName || ''}\nStarts: ${indiaTime(event.startAt)}\nEnds: ${indiaTime(event.endAt)}\nVenue: ${event.venue || 'To be announced'}\n\nOpen CampusSphere → My Registered Events → View QR ticket. Show your personal ticket to the event admin for attendance check-in.\n\nYour ticket is private. Do not share it with other students.\n\nCampusSphere`;
}
module.exports = {stableId,changedEvent,indiaTime,confirmationText};
