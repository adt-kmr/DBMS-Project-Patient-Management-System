-- Row-Level Security (RLS) & Temporal System-Versioning Setup for HMS
-- This script enables both Defense-in-Depth and Data Auditability.

-----------------------------------------------------------
-- PART 1: ROW-LEVEL SECURITY (RLS)
-----------------------------------------------------------

-- 1. Enable RLS on core data tables
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescribe ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies/functions (idempotency)
DROP POLICY IF EXISTS patient_access_policy ON patients;
DROP POLICY IF EXISTS report_access_policy ON reports;
DROP POLICY IF EXISTS prescribe_access_policy ON prescribe;

-- 3. Helper function to extract current session user
CREATE OR REPLACE FUNCTION get_current_employee_id() RETURNS INTEGER AS $$
  BEGIN
    RETURN NULLIF(current_setting('app.current_employee_id', TRUE), '')::INTEGER;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Set up Security Policies
CREATE POLICY patient_access_policy ON patients FOR ALL USING (
  EXISTS (SELECT 1 FROM employees e WHERE e.employeeid = get_current_employee_id() AND e.role = 'admin')
  OR patientid IN (SELECT patientid FROM prescribe WHERE employeeid = get_current_employee_id())
);

CREATE POLICY report_access_policy ON reports FOR ALL USING (
  EXISTS (SELECT 1 FROM employees e WHERE e.employeeid = get_current_employee_id() AND e.role = 'admin')
  OR patientid IN (SELECT patientid FROM prescribe WHERE employeeid = get_current_employee_id())
);

CREATE POLICY prescribe_access_policy ON prescribe FOR ALL USING (
  EXISTS (SELECT 1 FROM employees e WHERE e.employeeid = get_current_employee_id() AND e.role = 'admin')
  OR employeeid = get_current_employee_id()
);


-----------------------------------------------------------
-- PART 2: TEMPORAL SYSTEM-VERSIONING (Audit Trail)
-----------------------------------------------------------

-- 1. Create history table to store old versions of patient records
CREATE TABLE IF NOT EXISTS patient_history (
    id SERIAL PRIMARY KEY,
    patientid INTEGER NOT NULL,
    name VARCHAR(100),
    age INTEGER,
    gender VARCHAR(10),
    phone_number VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER, -- Captured via get_current_employee_id()
    operation VARCHAR(10) -- 'UPDATE' or 'DELETE'
);

-- 2. Trigger function to archive the OLD state before any modification
CREATE OR REPLACE FUNCTION archive_patient_history()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO patient_history (patientid, name, age, gender, phone_number, changed_by, operation)
        VALUES (OLD.patientid, OLD.name, OLD.age, OLD.gender, OLD.phone_number, get_current_employee_id(), 'DELETE');
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO patient_history (patientid, name, age, gender, phone_number, changed_by, operation)
        VALUES (OLD.patientid, OLD.name, OLD.age, OLD.gender, OLD.phone_number, get_current_employee_id(), 'UPDATE');
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach history trigger
DROP TRIGGER IF EXISTS patient_changes_trigger ON patients;
CREATE TRIGGER patient_changes_trigger
BEFORE UPDATE OR DELETE ON patients
FOR EACH ROW EXECUTE FUNCTION archive_patient_history();

-- 4. Enable RLS on History too! (Self-Defense for Audit trails)
ALTER TABLE patient_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS history_access_policy ON patient_history;

CREATE POLICY history_access_policy ON patient_history
FOR SELECT
USING (
  EXISTS (SELECT 1 FROM employees e WHERE e.employeeid = get_current_employee_id() AND e.role = 'admin')
  OR patientid IN (SELECT patientid FROM prescribe WHERE employeeid = get_current_employee_id())
);


-----------------------------------------------------------
-- PART 3: CRYPTOGRAPHIC RECORD INTEGRITY (Hash-Chaining)
-----------------------------------------------------------

-- 1. Enable pgcrypto for SHA256 functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Add hashing columns to the Report table
ALTER TABLE reports ADD COLUMN IF NOT EXISTS previous_hash TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS current_hash TEXT;

-- 3. Trigger function to calculate mathematical linkage
CREATE OR REPLACE FUNCTION calculate_report_hash()
RETURNS TRIGGER AS $$
DECLARE
    prev_hash TEXT;
BEGIN
    -- Find the most recent report's hash for this specific patient
    SELECT current_hash INTO prev_hash 
    FROM reports 
    WHERE patientid = NEW.patientid 
    ORDER BY date_uploaded DESC, reportid DESC 
    LIMIT 1;

    -- If first report, use a 'Genesis' seed hash
    IF prev_hash IS NULL THEN
        prev_hash := '0xGENESIS_SEED_00000000000000000000000000000000000000000000000000000';
    END IF;

    -- Store the linkage
    NEW.previous_hash := prev_hash;

    -- CRITICAL MATHEMATICAL STEP:
    -- We generate a SHA256 digest of (PatientID + ReportType + Date + PreviousHash)
    -- This ensures that if ANY field in the past or present is changed, the 
    -- math will no longer add up, alerting the system of tampering.
    NEW.current_hash := encode(digest(
        COALESCE(NEW.patientid::text, '0') || 
        COALESCE(NEW.type_, 'unknown') || 
        COALESCE(NEW.date_uploaded::text, 'now') || 
        prev_hash, 
        'sha256'
    ), 'hex');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Attach hashing trigger
DROP TRIGGER IF EXISTS report_hash_trigger ON reports;
CREATE TRIGGER report_hash_trigger
BEFORE INSERT ON reports
FOR EACH ROW EXECUTE FUNCTION calculate_report_hash();

-- 5. Verification View: Helps identify if the chain is broken
CREATE OR REPLACE VIEW health_integrity_audit AS
SELECT 
    reportid,
    patientid,
    type_ as report_type,
    current_hash,
    previous_hash,
    CASE 
        WHEN current_hash = encode(digest(
            COALESCE(patientid::text, '0') || 
            COALESCE(type_::text, 'unknown') || 
            COALESCE(date_uploaded::text, 'now') || 
            previous_hash, 
            'sha256'
        ), 'hex') THEN 'VERIFIED'
        ELSE 'TAMPERED_OR_CORRUPT'
    END as integrity_status
FROM reports;

