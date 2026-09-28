# Privacy

Written for the person using the app, and for the Play Store listing that will
require a policy before it accepts a health app.

Symptom history is among the most sensitive data a person holds. This app has
no accounts, no analytics and no server-side database, and the design below
follows from that rather than apologising for it.

---

## What stays on your phone

**Everything, by default.**

| Stored on the device | Where |
|---|---|
| Your health profile — name, age, sex, ongoing conditions, allergies, medications | `SharedPreferences` |
| Your assessment history — the most recent 40 results, in full | `SharedPreferences` |

**Your assessment history never leaves the device.** There is nowhere to sync
it to that would be safer than the phone it was created on, and adding an
account system would mean holding other people's symptom histories — which is
a responsibility this project does not want and could not discharge properly.

Every profile field is optional. The app works unchanged with an empty
profile, and an empty profile scores exactly as a filled one does except where
noted below.

Uninstalling the app deletes all of it. The history screen also has an erase
control.

---

## What is sent to the server, and why

Exactly two profile fields travel, only with an assessment, and only because
they change the result:

| Field | Sent | Why |
|---|---|---|
| Age | ✅ | Shifts the risk score; infants and older adults escalate differently |
| Ongoing conditions | ✅ | Feed comorbidity scoring — asthma with breathlessness changes the advice |
| Name | ❌ | No engine rule consumes it |
| Sex | ❌ | No engine rule consumes it |
| Allergies | ❌ | No engine rule consumes it |
| Medications | ❌ | No engine rule consumes it |
| Assessment history | ❌ | Never leaves the device |

The rule is that a field has to earn transmission by changing the output.
Uploading medical data that changes nothing is collection for its own sake.

Alongside those, an assessment sends the symptoms you typed, the duration and
severity you selected, and your answers to the follow-up questions. That is
what the assessment *is*; there is no way to perform it without them.

---

## What the server keeps

**The stateless API (`backend/api/`) keeps nothing.** Conversation state is
signed and handed back to your device between turns, and returns with your
next message. The server holds no session, no database and no symptom record —
there is nothing to leak, subpoena, or forget to delete.

**The Rasa server keeps a conversation in memory** for the duration of your
session, and loses it on restart. It is not written to disk, because no
tracker store is configured.

**Logs.** The server logs that an emergency red flag was matched and which
phrase matched it. It does **not** log crisis disclosures — a suicidal
disclosure records only that a crisis was detected, never the words. Symptom
text is not logged at any level.

---

## Third parties

**Hospital search (Geoapify).** When you ask for nearby hospitals, your
device — not our server — sends your coordinates to Geoapify. The backend
never learns your location; it only signals that a search is warranted. Their
privacy policy governs that request.

**Phone and maps.** Tapping a phone number or directions hands off to your
device's own dialler or map app.

**Nothing else.** No analytics SDK, no crash reporter, no advertising
identifier, no third-party tracking of any kind.

---

## Permissions

| Permission | Used for | Optional |
|---|---|---|
| Location | Finding hospitals near you | Yes — declining only disables that feature |
| Internet | Reaching the triage server | Required |

---

## Security, stated plainly

Communication with a deployed backend uses HTTPS, and a release build refuses
to ship pointed at a cleartext address.

The shared token the app uses to reach the backend is compiled into the
binary and is therefore **extractable by anyone holding the app**. It stops an
open port being driven by a passer-by; it does not authenticate *you*, and it
is not a secret in any strong sense. Per-user authentication would need a
backend that issues credentials, which this project does not have.

---

## Children

The risk engine explicitly models infants and children, so the app may be used
by an adult on a child's behalf. It collects nothing beyond what is described
above in that case, and stores it the same way — on the device.

---

## Changes

This file is versioned with the code. Its history is the change log.

---

*See [INTENDED_USE.md](INTENDED_USE.md) for what this software is and is not
intended to be used for. It is an educational project, not a medical device.*
