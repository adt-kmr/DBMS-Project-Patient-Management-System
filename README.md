# Patient Management System: Enterprise-Grade Medical Data Engine

> A full-stack Hospital Information System built as a DBMS course project at Thapar University, implementing production-level database security, audit-trail versioning, and cryptographic record integrity; features that are standard in banking and cloud platforms, but virtually absent in open Patient Management Systems today.

---

## Table of Contents

- [Project Overview](#project-overview)
- [System Architecture](#system-architecture)
- [Core Features](#core-features)
- [Novelty Features](#novelty-features)
  - [1. Row-Level Security — Defense in Depth](#1-row-level-security--defense-in-depth)
  - [2. Temporal System-Versioning — The Medical Time Machine](#2-temporal-system-versioning--the-medical-time-machine)
  - [3. Cryptographic Hash-Chaining — Tamper-Evident Records](#3-cryptographic-hash-chaining--tamper-evident-records)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Project Structure](#project-structure)
- [Team](#team)

---

## Project Overview

This system is a **Hospital Patient Management Platform** designed to digitize and secure the clinical workflows of a hospital environment. At its surface, it allows doctors and administrators to manage patient records, prescriptions, and medical reports through a clean cross-platform interface. Under the hood, it is architected as a **Medical Data Engine** — where data privacy, historical accuracy, and tamper-resistance are enforced at the database kernel level, not just the application layer.

### What the System Does

**For Doctors:**
- Register new patients with demographic details
- View their assigned patient list
- Create and manage prescriptions tied to a patient
- Upload and review medical reports

**For Administrators:**
- Manage hospital-wide patient and doctor records
- Access full audit logs and record history
- Run integrity checks on the medical report chain

**For the Database:**
- Enforces access rules *inside* PostgreSQL — not just in application code
- Automatically archives a complete history of every record change
- Mathematically seals every medical report against undetected tampering

The project scope is deliberately aligned with real-world healthcare compliance needs: the architecture mirrors what HIPAA-compliant systems, insurance providers, and medical litigation bodies require from a trustworthy health record platform.

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Clients                               │
│         Flutter App (Mobile/Web)  ·  Admin Dashboard         │
└───────────────────────┬──────────────────────────────────────┘
                        │ HTTPS / REST
┌───────────────────────▼──────────────────────────────────────┐
│                   Python Backend (FastAPI/Flask)              │
│   JWT Auth  ·  Route Handlers  ·  DB Session Context Piping  │
└───────────────────────┬──────────────────────────────────────┘
                        │ psycopg2 / SQL
┌───────────────────────▼──────────────────────────────────────┐
│                      PostgreSQL Engine                        │
│                                                              │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │  Row-Level  │  │  Trigger-based   │  │  Hash-Chained  │  │
│  │  Security   │  │  Audit Trail     │  │  Report Ledger │  │
│  │  (RLS)      │  │  (patient_hist.) │  │  (SHA-256)     │  │
│  └─────────────┘  └──────────────────┘  └────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## Core Features

| Feature | Description |
|---|---|
| Patient Registration | Add patients with name, age, gender, contact |
| Patient Records | View, update, and soft-delete records |
| Prescription Management | Doctors issue prescriptions linked to patients |
| Medical Reports | Upload and retrieve diagnostic reports |
| Role-Based Auth | JWT-based login with doctor and admin roles |
| Admin Dashboard | Hospital-wide data visibility and controls |
| Dockerized Deployment | Full environment via `docker-compose` |

---

## Novelty Features

> Each of these features is implemented *entirely at the PostgreSQL level*; using Triggers, Functions, Views, and Policies — demonstrating advanced SQL well beyond standard CRUD operations.

---

### 1. Row-Level Security — Defense in Depth

#### The Problem with the Status Quo

In virtually every open-source or academic Patient Management System available today, data access is controlled exclusively by the application layer. A Python or Node.js route checks `WHERE doctor_id = ?` before returning records. This works — until it doesn't. A missing `WHERE` clause in a new route, a subtle middleware bug, or a direct SQL injection bypassing the API entirely would expose the *entire* patient database to any caller.

This is not a theoretical concern. A 2023 IBM report found that healthcare data breaches cost an average of $10.9 million per incident — the highest of any industry, for the 13th consecutive year. Most of these breaches were attributed to insufficient access controls at the data layer.

#### What We Did Differently

We moved the access control logic into the **PostgreSQL kernel itself** using Row-Level Security (RLS) Policies.

```sql
-- Example: A doctor can only SELECT patients they have an active prescription for
CREATE POLICY patient_access_policy ON patients
  FOR SELECT
  USING (
    patient_id IN (
      SELECT patient_id FROM prescriptions
      WHERE doctor_id = current_setting('app.current_doctor_id')::INT
    )
  );
```

Every table — `patients`, `reports`, `prescriptions` — is locked with a dedicated policy. A bare `SELECT * FROM patients` executed directly in `psql` returns **zero rows** unless the database session carries the identity of an authorized doctor with active prescriptions.

The Python backend "pipes" the authenticated doctor's ID from the decoded JWT token into the PostgreSQL session context before executing any query. The database then enforces the policy transparently.

#### Where This Exists Today

RLS is a core feature of enterprise platforms:

- **Supabase** (the Firebase alternative) markets RLS as its primary security model for all user-facing databases
- **Amazon Aurora PostgreSQL** and **Google Cloud AlloyDB** both recommend RLS for multi-tenant SaaS applications
- **Banking core systems** use analogous cell-level security to ensure a bank employee in Branch A cannot query customer records from Branch B

#### Why This Is Novel in Patient Management

Open Patient Management Systems (OpenMRS, GNU Health, Bahmni) handle access control in their application middleware. None enforce it at the data layer via RLS. This means a sufficiently privileged database user — a DBA, a compromised admin account, or an attacker with DB credentials — can access *any* record directly. In our system, that attack surface is closed. The database itself is an intelligent firewall.

---

### 2. Temporal System-Versioning — The Medical Time Machine

#### The Problem with the Status Quo

When a doctor updates a patient's blood type from `O+` to `A+`, or changes a prescription dosage, what happens to the old value? In a standard HMS — it is gone. Overwritten. The database only holds the current state.

This is a fundamental problem in healthcare:

- **Clinical**: A patient presents with an adverse drug reaction. The attending physician needs to know what the previous prescription was. That information does not exist.
- **Legal**: A malpractice lawsuit claims a record was altered. There is no way to prove or disprove what the record contained last year.
- **Research**: Epidemiologists want to track how patient demographics or diagnoses evolved over time. Manual logging is inconsistent and incomplete.

#### What We Did Differently

We implemented a **Shadow Audit Trail** using PostgreSQL Triggers that activate on every `UPDATE` and `DELETE`.

```sql
CREATE OR REPLACE FUNCTION archive_patient_on_change()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO patient_history (
    patient_id, name, age, gender, phone_number,
    changed_by_doctor_id, changed_at, change_type
  )
  VALUES (
    OLD.patient_id, OLD.name, OLD.age, OLD.gender, OLD.phone_number,
    current_setting('app.current_doctor_id')::INT,
    NOW(),
    TG_OP  -- 'UPDATE' or 'DELETE'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Key properties of this implementation:

- **Every UPDATE**: The exact state of the record *before* the change is archived into `patient_history`
- **Every DELETE**: The record is moved to history rather than permanently erased — no data is ever truly lost
- **Who & When**: The trigger automatically captures the `doctor_id` from the session context and the precise timestamp — no developer has to remember to log this manually
- **Immutable**: The history table itself is append-only; RLS prevents any modification to past entries

This gives the system a "Medical Time Machine" — an administrator or consultant can reconstruct exactly what a patient's record looked like at any point in its entire history.

#### Where This Exists Today

Temporal versioning at the database level is used in:

- **Financial services**: Trade ledgers, transaction histories, and account statement archives are legally required to retain every state change (SEC Rule 17a-4)
- **Git / Version Control**: The concept is identical to how Git stores every commit — not just the current file
- **Slowly Changing Dimensions (SCD Type 2)**: A standard data warehousing pattern in analytics systems (Snowflake, BigQuery)
- **FHIR Standard (HL7)**: The healthcare interoperability standard *recommends* versioned resources, but leaves implementation to vendors

#### Why This Is Novel in Patient Management

While the FHIR standard *recommends* resource versioning, the vast majority of Patient Management Systems — especially open-source ones — do not implement it at the database trigger level. Versioning in those systems, when it exists at all, is handled inconsistently in application code, making it easy to bypass, forget, or corrupt. Our trigger-level implementation is **automatic and mandatory** — it cannot be forgotten by a developer writing a new route.

---

### 3. Cryptographic Hash-Chaining — Tamper-Evident Records

#### The Problem with the Status Quo

Consider this scenario: A patient is diagnosed with a minor condition. Years later, in a legal dispute, someone with database access changes the diagnosis to something more severe. They run:

```sql
UPDATE reports SET diagnosis = 'Critical' WHERE report_id = 42;
```

In a traditional HMS, there is **no mathematical way to detect this**. The audit trail may exist in application logs, but logs can be deleted too. The record simply shows the current value. It was always "Critical."

This is not paranoia. Medical record tampering is documented in malpractice cases worldwide, and is increasingly a concern as Electronic Health Records become the primary — and sometimes sole — evidence in legal proceedings.

#### What We Did Differently

We implemented a **Hash-Chaining mechanism** — the same mathematical principle that makes blockchain records tamper-evident — applied directly to the medical reports table using native PostgreSQL cryptographic functions.

```sql
-- On each INSERT into reports, a trigger computes:
new_hash = SHA256(
  patient_id::TEXT ||
  report_type       ||
  report_date::TEXT ||
  previous_hash
)
```

The `previous_hash` is the hash of the immediately preceding report for that patient. This creates a **chain**: each record is mathematically linked to the one before it. If any record in the past is silently modified, its hash will no longer match the `previous_hash` stored in the *next* record. The chain "breaks."

We also implemented an integrity audit view:

```sql
CREATE VIEW health_integrity_audit AS
SELECT
  report_id,
  patient_id,
  stored_hash,
  encode(
    digest(patient_id::TEXT || type || date::TEXT || prev_hash, 'sha256'),
    'hex'
  ) AS computed_hash,
  CASE
    WHEN stored_hash = encode(digest(...), 'hex')
    THEN 'VALID'
    ELSE 'TAMPERED_OR_CORRUPT'
  END AS integrity_status
FROM reports;
```

Running a query on this view re-derives every hash from scratch and flags any record where the math does not match.

#### Where This Exists Today

Hash-chaining is used in:

- **Bitcoin / Ethereum**: Every block header contains the hash of the previous block — tampering with one block invalidates every subsequent block
- **Certificate Transparency Logs (Google)**: A public audit log of SSL certificates using a Merkle tree (a hash-chain variant), now mandatory for all certificates trusted by Chrome
- **Financial audit logs**: Some high-security banking systems use append-only hash-chained logs for transaction records
- **WORM Storage + Hashing**: Healthcare archival systems (Iron Mountain, Dell EMC) use hash verification to guarantee that archived records have not been modified

#### Why This Is Novel in Patient Management

No mainstream open-source Patient Management System implements hash-chaining at the database level for medical reports. The standard approach is to rely on database access controls and application-layer logging — both of which can be bypassed by a sufficiently privileged attacker. Our implementation provides **mathematical proof of integrity that is independent of trust in any person or system**. You do not need to trust the DBA. You do not need to trust the application. You trust SHA-256.

In medical malpractice cases, this provides irrefutable cryptographic evidence that a report has not been altered since it was first created — something no other open Patient Management System can currently offer.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python (FastAPI / Flask) |
| Frontend | Flutter (Dart) — cross-platform mobile & web |
| Admin Dashboard | JavaScript |
| Database | PostgreSQL (RLS, Triggers, Functions, Views) |
| Auth | JWT (piped to DB session context) |
| Containerization | Docker + Docker Compose |
| Environment | Python virtualenv, `.env` config |

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.10+
- Flutter SDK (for mobile frontend)

### 1. Clone the Repository

```bash
git clone https://github.com/adt-kmr/DBMS-Project-Patient-Management-System.git
cd DBMS-Project-Patient-Management-System
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your DB credentials and JWT secret
```

### 3. Start with Docker

```bash
docker-compose up --build
```

This starts the PostgreSQL instance and the Python backend. The database schema, RLS policies, triggers, and hash-chaining functions are initialized automatically on first run.

### 4. Run the Frontend

```bash
cd pgi_app
flutter pub get
flutter run
```

See [`READMEs/ForFrontendDevs.md`](./READMEs/ForFrontendDevs.md) and [`READMEs/ForBackendDevs.md`](./READMEs/ForBackendDevs.md) for detailed developer setup guides.

---

## API Reference

### Patients

| Method | Route | Description |
|---|---|---|
| `POST` | `/add-patient` | Register a new patient |
| `GET` | `/get-patients` | Retrieve all accessible patients |
| `PUT` | `/edit-patient/:patientid` | Update patient details |
| `DELETE` | `/edit-patient/:patientid` | Soft-delete a patient |

#### Add Patient — Request Body
```json
{
  "name": "string",
  "age": 30,
  "gender": "male" | "female",
  "phone_number": "string"
}
```

#### Get Patients — Response
```json
[
  {
    "patientid": 1,
    "name": "string",
    "age": 30,
    "gender": "male",
    "phone_number": "string"
  }
]
```

All fields in `PUT /edit-patient/:id` are optional — send only the fields you wish to update.

---

## Project Structure

```
.
├── backend/          # Python API server (routes, DB connection, auth)
├── pgi_app/          # Flutter frontend application
├── admin/            # Admin dashboard (JavaScript)
├── auth/             # Authentication module (JWT issue & verification)
├── READMEs/          # Developer guides (frontend & backend)
├── NOVELTY_FEATURES.md
├── docker-compose.yml
├── .env
└── README.md
```

---

## Key Design Decisions

**Security lives in the database, not the application.** Most systems trust their application code to enforce access rules. We treat the application as an untrusted client — the database enforces every access policy independently.

**History is immutable.** Records are never truly deleted. Every change is timestamped, attributed to a doctor, and stored permanently. The application cannot suppress or modify this history.

**Integrity is mathematical, not procedural.** We do not rely on access logs, admin honesty, or application-layer checks to guarantee that records have not been tampered with. SHA-256 hash chains provide proof that is independent of any trust assumption.

---

## Team

Built as a DBMS Course Project.

| Name | Role |
|---|---|
| Aditya Kumar | Database Architecture + Adding Novel Features |
| Baltej Singh | Frontend + Backend + Admin Dashboard + Auth |

---

## License

This project is for academic and educational purposes.

---

*"Don't trust the middleware. Trust the math."*

# ReadMEs
- For frontend devs: [./READMEs/ForFrontendDevs.md](./READMEs/ForFrontendDevs.md)
- For backend devs: [./READMEs/ForBackendDevs.md](./READMEs/ForBackendDevs.md)

