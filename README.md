## 1. Short Description
This mobile application for a holistic wellness clinic aims to solve a key issue with modern healthcare: the impersonal and fragmented patient experience. The app provides a seamless and user-friendly platform that empowers users to take control of their wellness journey by connecting them directly with various holistic practitioners.

The app focuses exclusively on **integrated wellness management** - users can book, track, and review appointments for a wide range of services like acupuncture, massage therapy, nutritional counseling, and mental health consultations, ensuring a cohesive and personalized experience. Appointment and user data are securely managed, guaranteeing an authentic and private user experience.

---

## 2. Domain Details

### User Entity
| Field | Description |
|---|---|
| **id** | Unique identifier for a user |
| **email** | Email address of the user |
| **password** | Password for the user account |
| **name** | Full name of the user |
| **phone** | Phone number for communication and notifications |

### Practitioner Entity
| Field | Description |
|---|---|
| **id** | Unique identifier of a practitioner |
| **name** | Full name of the practitioner |
| **specialty** | Area of expertise (e.g., Massage, Acupuncture, Nutrition) |
| **bio** | Detailed biography and professional experience |
| **photo** | Link to the practitioner’s profile picture |
| **rating** | Average rating from user reviews |

### Appointment Entity
| Field | Description |
|---|---|
| **id** | Unique identifier of an appointment |
| **user_id** | ID of the user who booked the appointment |
| **practitioner_id** | ID of the practitioner for the appointment |
| **service** | The specific service booked (e.g., Deep Tissue Massage, Initial Consultation) |
| **datetime** | Timestamp of the scheduled appointment |
| **status** | Current status of the appointment (e.g., Booked, Completed, Canceled) |

---

## 3. CRUD Operations

### User Entity
| Operation | Description |
|---|---|
| **Create** | When a new user registers an account on the app |
| **Read** | When the app needs to load user profile details |
| **Update** | When a user updates their personal information |
| **Delete** | When a user requests to delete their account |

### Practitioner Entity
| Operation | Description |
|---|---|
| **Create** | When a new practitioner is onboarded into the system (admin function) |
| **Read** | When the app displays the list of practitioners and their details |
| **Update** | When a practitioner updates their professional details (admin function) |
| **Delete** | When a practitioner is removed from the system (admin function) |

### Appointment Entity
| Operation | Description |
|---|---|
| **Create** | When a user books a new appointment |
| **Read** | When the app loads the user’s upcoming or past appointments |
| **Update** | When a user or practitioner modifies appointment details (e.g., rescheduling) |
| **Delete** | When a user or practitioner cancels an appointment |

---

## 4. Persistence Details

The app uses a hybrid persistence model, storing data both on the server and a local database on the device.

* **User Read** and **Practitioner Read** operations are persisted on the local database to allow offline access. They are always synced from the server to ensure they are up-to-date.
* **Appointment Create**, **Update**, and **Delete** operations are persisted on the local database and automatically synced with the server when a connection is available.
* All other CRUD operations for all entities are persisted on the server, as they require a constant connection for security and data consistency.

---

## 5. Offline Functionality

The app is designed with a "sync-on-return" strategy, allowing users to perform key actions even without an internet connection. Changes made offline are queued and automatically synced with the server when the device reconnects.

* **Create (Appointment):** When a user books a new appointment offline, it is saved locally and marked as "pending." The app automatically sends the request to the server when a connection is restored.
* **Read (Appointment):** All appointment data is cached from the last successful sync, allowing the user to view their upcoming and past appointments offline.
* **Update (Appointment):** Changes to an appointment made offline are stored locally in a queue. When the device is back online, the app sends the update request to the server.
* **Delete (Appointment):** Deleting an appointment offline removes it from the local view and queues a deletion request to be sent to the server upon reconnection.

---

## 6. App Mockup

####  Home Page with List of Services, Appointments List Page, and Add an Appointment Page

<img width="295" height="980" alt="image" src="https://github.com/user-attachments/assets/5ea9beb7-da8e-4719-afbf-83b1b7ef742a" />
<img width="295" height="980" alt="image" src="https://github.com/user-attachments/assets/a30a8512-dea8-419d-a430-9b7420a3208c" />
<img width="295" height="980" alt="image" src="https://github.com/user-attachments/assets/96d2600d-fb35-41fe-b0ac-70d8bcc54246" />
