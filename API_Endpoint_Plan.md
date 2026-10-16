# RaceDay – API Endpoint Plan (Part 1, Section B)

**Base URL:** `https://localhost:{port}/api` · **Format:** JSON · **Auth:** JWT Bearer token returned by login (`Authorization: Bearer <token>`), carrying the user's `UserId` and `Role` claims. Role checks are enforced on the API with `[Authorize(Roles = "...")]` (Part 2).
**Roles:** `Anonymous` = no login · `Any` = Organiser or Participant · `Organiser` · `Participant`

**Standard error responses (all endpoints):** `400 Bad Request` (validation failed) · `401 Unauthorized` (no/invalid token) · `403 Forbidden` (wrong role or not the owner) · `404 Not Found` · `409 Conflict` (duplicate / rule violation) · `500 Internal Server Error`.

---

## 1. Authentication

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 1 | POST | `/api/auth/register` | Register a new account as Organiser or Participant. Email must be unique; password is hashed (BCrypt) before saving. | Anonymous | `{ firstName, lastName, email, password, role ("Organiser"\|"Participant"), dateOfBirth, gender, phoneNumber?, province?, emergencyContactName?, emergencyContactNumber? }` | `201 Created` `{ userId, email, role }` · `409` email exists |
| 2 | POST | `/api/auth/login` | Authenticate with email + password. | Anonymous | `{ email, password }` | `200 OK` `{ token, expiresAt, userId, firstName, role }` · `401` invalid credentials |
| 3 | POST | `/api/auth/logout` | End the current session (client discards token; server records logout). | Any | none | `204 No Content` |

## 2. User Profile

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 4 | GET | `/api/users/me` | View own profile (never returns the password hash). | Any | none | `200 OK` `{ userId, firstName, lastName, email, role, phoneNumber, dateOfBirth, gender, province, emergencyContactName, emergencyContactNumber }` |
| 5 | PUT | `/api/users/me` | Update own profile details (email and role cannot be changed here). | Any | `{ firstName, lastName, phoneNumber?, dateOfBirth, gender, province?, emergencyContactName?, emergencyContactNumber? }` | `200 OK` updated profile · `400` |
| 6 | PUT | `/api/users/me/password` | Change own password. | Any | `{ currentPassword, newPassword }` | `204 No Content` · `400` wrong current password |

## 3. Events

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 7 | GET | `/api/events` | List events. Optional query: `type` (Run/Walk/Cycle), `from`, `to`, `search`, `upcoming=true`. | Any | none | `200 OK` `[ { eventId, name, description, eventDate, location, distanceKm, eventType, organiserName, maxParticipants } ]` |
| 8 | GET | `/api/events/{eventId}` | View one event including its categories. | Any | none | `200 OK` event detail + `categories[]` · `404` |
| 9 | GET | `/api/events/mine` | List events created by the logged-in Organiser. | Organiser | none | `200 OK` `[ event ]` |
| 10 | POST | `/api/events` | Create an event (organiser = logged-in user). | Organiser | `{ name, description, eventDate, location, distanceKm, eventType ("Run"\|"Walk"\|"Cycle"), maxParticipants? }` | `201 Created` event + `Location` header · `400` |
| 11 | PUT | `/api/events/{eventId}` | Update an event. Only the owning Organiser may do so. | Organiser (owner) | same as POST | `200 OK` updated event · `403` · `404` |
| 12 | DELETE | `/api/events/{eventId}` | Delete an event (cascades to its categories, enrolments and results). Owner only. | Organiser (owner) | none | `204 No Content` · `403` · `404` |

## 4. Categories

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 13 | GET | `/api/events/{eventId}/categories` | List categories available for an event. | Any | none | `200 OK` `[ { categoryId, eventId, name, categoryType, minAge, maxAge, distanceKm, entryFee } ]` · `404` event |
| 14 | GET | `/api/categories/{categoryId}` | View a single category. | Any | none | `200 OK` category · `404` |
| 15 | POST | `/api/events/{eventId}/categories` | Add an age or distance category to an event. Name must be unique within the event. | Organiser (owner) | `{ name, categoryType ("Age"\|"Distance"), minAge?, maxAge?, distanceKm?, entryFee }` | `201 Created` category · `400` · `403` · `409` duplicate name |
| 16 | PUT | `/api/categories/{categoryId}` | Update a category. | Organiser (owner) | same as POST | `200 OK` category · `403` · `404` |
| 17 | DELETE | `/api/categories/{categoryId}` | Delete a category (rejected if participants are already enrolled in it). | Organiser (owner) | none | `204 No Content` · `409` has enrolments · `403` · `404` |

## 5. Event Enrolments

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 18 | POST | `/api/enrolments` | Enter an event by choosing a category. Links Participant + Event + Category. Rules: one entry per participant per event, category must belong to the event, event must be in the future and not full, age must fit an age category. | Participant | `{ eventId, categoryId }` | `201 Created` `{ enrolmentId, eventId, eventName, categoryId, categoryName, raceNumber, status, enrolledAt }` · `409` already entered / event full · `400` invalid category |
| 19 | GET | `/api/enrolments/mine` | View all of my enrolments. | Participant | none | `200 OK` `[ enrolment ]` |
| 20 | GET | `/api/enrolments/{enrolmentId}` | View a single enrolment (own only). | Participant (owner) | none | `200 OK` enrolment · `403` · `404` |
| 21 | DELETE | `/api/enrolments/{enrolmentId}` | Withdraw from an event (own enrolment, before event date). | Participant (owner) | none | `204 No Content` · `403` · `404` · `409` event already held |
| 22 | GET | `/api/events/{eventId}/enrolments` | View every enrolment for one of the organiser's events (participant name, category, race number). Optional `categoryId` filter. | Organiser (owner) | none | `200 OK` `[ { enrolmentId, participantId, participantName, categoryName, raceNumber, enrolledAt } ]` · `403` · `404` |

## 6. Results

| # | HTTP Method | Route | Description | Role Required | Request Body | Expected Response |
|---|---|---|---|---|---|---|
| 23 | POST | `/api/results` | Capture a finish time and position for an enrolment of the organiser's event. One result per enrolment. | Organiser (owner) | `{ enrolmentId, finishTime ("HH:mm:ss"), overallPosition, categoryPosition?, resultStatus ("Finished"\|"DNF"\|"DNS"\|"DSQ") }` | `201 Created` result · `400` · `403` · `409` result exists |
| 24 | PUT | `/api/results/{resultId}` | Correct a captured result. | Organiser (owner) | `{ finishTime, overallPosition, categoryPosition?, resultStatus }` | `200 OK` result · `403` · `404` |
| 25 | DELETE | `/api/results/{resultId}` | Remove a captured result. | Organiser (owner) | none | `204 No Content` · `403` · `404` |
| 26 | GET | `/api/events/{eventId}/results` | View all results for an event, ordered by overall position. | Organiser (owner) | none | `200 OK` `[ { resultId, participantName, categoryName, raceNumber, finishTime, overallPosition, categoryPosition, resultStatus } ]` |
| 27 | GET | `/api/results/mine` | View my own results history (event, date, category, time, positions). | Participant | none | `200 OK` `[ { resultId, eventName, eventDate, distanceKm, categoryName, finishTime, overallPosition, categoryPosition, resultStatus } ]` |

---

### Notes / planned design decisions
* **27 endpoints** cover all required areas: Authentication, User Profile, Events, Categories, Event Enrolments, Results.
* **Ownership rule:** an Organiser can only change/view enrolments and results of events where `Events.OrganiserId` = their `UserId`.
* **Participants** can only see their own enrolments and results (`mine` routes use the `UserId` claim – never an id from the URL).
* **Part 3 extras (planned, not part of Part 2 API):** the MVC app will call a weather service for race-day forecasts and upload event route/profile images to Azure Blob Storage.
* **Swagger:** every endpoint is annotated with `[ProducesResponseType]` and XML summaries, and the Swagger UI has a Bearer "Authorize" button.
