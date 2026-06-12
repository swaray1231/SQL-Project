USE UniHospital ;
GO
---- 3.1 a: Patient admission procedure
---- Admits a patient to a ward , validates capacity , creates an Admission
---- record , and returns the new AdmissionID via an OUTPUT parameter .
--CREATE OR ALTER PROCEDURE usp_AdmitPatient
--@PatientID INT ,
--@WardID INT ,
--@DiagnosisCode NVARCHAR (20) ,
--@AdmissionID INT OUTPUT
--AS
--BEGIN
--SET NOCOUNT ON;
--SET XACT_ABORT ON;
--BEGIN TRY
--BEGIN TRANSACTION ;
---- Check ward capacity
--DECLARE @Capacity INT ,
--@CurrentOcc INT;
--SELECT @Capacity = Capacity FROM Ward WHERE WardID =
--@WardID ;
--SELECT @CurrentOcc = COUNT (*)
--FROM Admission
--WHERE WardID = @WardID
--AND DischargeDate IS NULL ;
--IF @CurrentOcc >= @Capacity
--THROW 50001 ,'Ward is at full capacity .', 1;
--INSERT INTO Admission ( PatientID , WardID ,DiagnosisCode)
--VALUES ( @PatientID , @WardID , @DiagnosisCode );
--SET @AdmissionID = SCOPE_IDENTITY ();
--COMMIT TRANSACTION ;
--END TRY
--BEGIN CATCH
--IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION ;
--THROW ;
--END CATCH ;
--END ;
--GO

-- 3.2 b: TODO - Inline TVF : fn_PatientHistory ( @PatientID INT)
-- Returns a chronological list of appointments , admissions ,
-- prescriptions , and bills for a given patient .

CREATE OR ALTER FUNCTION dbo.fn_PatientHistory
(
    @PatientID INT
)
RETURNS TABLE
AS
RETURN
(
    -- 1. Appointment Timeline Records
    SELECT 
        ApptDate AS EventDate,
        'Appointment' AS EventType,
        'Appt ID: ' + CAST(AppointmentID AS VARCHAR(10)) + ' | Status: ' + ISNULL(Status, 'Scheduled') AS EventDetails
    FROM Appointment
    WHERE PatientID = @PatientID

    UNION ALL

    SELECT 
        AdmitDate AS EventDate,
        'Admission' AS EventType,
        'Admission ID: ' + CAST(AdmissionID AS VARCHAR(10)) + ' | Ward: ' + CAST(WardID AS VARCHAR(10)) AS EventDetails
    FROM Admission
    WHERE PatientID = @PatientID

    UNION ALL

      SELECT 
        p.PrescDate AS EventDate,
        'Prescription' AS EventType,
        'Medication ID: ' + CAST(p.MedID AS VARCHAR(10)) + ' | Dosage: ' + ISNULL(p.Quantity, 'N/A') AS EventDetails
    FROM Prescription p
    INNER JOIN Admission a ON p.AdmissionID = a.AdmissionID
    WHERE a.PatientID = @PatientID

    UNION ALL

    SELECT 
        BillDate AS EventDate,
        'Billing' AS EventType,
        'Bill ID: ' + CAST(BillID AS VARCHAR(10)) + ' | Total Amount: $' + CAST(TotalAmount AS VARCHAR(15)) AS EventDetails
    FROM Bill
    WHERE PatientID = @PatientID
);
GO


-- 3.1 c: TODO - Write usp_DoctorWorkloadReport

-- Returns a result set showing each doctor  s appointment count ,
-- admission count , and average bill value for a given date range
-- 3.2 a: Scalar function calculate patient age from DOB
--CREATE OR ALTER FUNCTION dbo . fn_PatientAge
--( @DOB DATE )
--RETURNS INT
--AS
--BEGIN
--RETURN DATEDIFF (YEAR , @DOB , GETDATE ())
--- CASE WHEN FORMAT ( GETDATE () ,'MMdd') < FORMAT (@DOB ,'MMdd')
--THEN 1 ELSE 0 END ;
--END ;
--GO

-- 3.2 b: TODO - Inline TVF : fn_PatientHistory ( @PatientID INT)
-- Returns a chronological list of appointments , admissions ,
-- prescriptions , and bills for a given patient .
CREATE OR ALTER FUNCTION dbo.fn_PatientHistory
(
    @PatientID INT
)
RETURNS TABLE
AS
RETURN
(
    -- 1. Appointment Timeline Records
    SELECT 
        ApptDate AS EventDate,
        'Appointment' AS EventType,
        'Appt ID: ' + CAST(AppointmentID AS VARCHAR(10)) + ' | Status: ' + ISNULL(Status, 'Scheduled') AS EventDetails
    FROM Appointment
    WHERE PatientID = @PatientID

    UNION ALL

    -- 2. Admission Timeline Records
    SELECT 
        AdmitDate AS EventDate,
        'Admission' AS EventType,
        'Admission ID: ' + CAST(AdmissionID AS VARCHAR(10)) + ' | Ward: ' + CAST(WardID AS VARCHAR(10)) AS EventDetails
    FROM Admission
    WHERE PatientID = @PatientID

    UNION ALL

    -- 3. Prescription Timeline Records (Linked through Patient's Admissions)
    SELECT 
        p.PrescDate AS EventDate,
        'Prescription' AS EventType,
        'Medication ID: ' + CAST(p.MedID AS VARCHAR(10)) + ' | Dosage: ' + ISNULL(p.Quantity, 'N/A') AS EventDetails
    FROM Prescription p
    INNER JOIN Admission a ON p.AdmissionID = a.AdmissionID
    WHERE a.PatientID = @PatientID

    UNION ALL

    -- 4. Billing Timeline Records
    SELECT 
        BillDate AS EventDate,
        'Billing' AS EventType,
        'Bill ID: ' + CAST(BillID AS VARCHAR(10)) + ' | Total Amount: $' + CAST(TotalAmount AS VARCHAR(15)) AS EventDetails
    FROM Bill
    WHERE PatientID = @PatientID
);
GO

-- 3.2 c: TODO - Scalar function : fn_OutstandingBalance ( @PatientID INT)
-- Returns the total unpaid balance across all bills for the patient .
CREATE OR ALTER FUNCTION dbo.fn_OutstandingBalance
(
    @PatientID INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TotalOutstanding DECIMAL(18, 2);

    -- Calculating the total unpaid
    SELECT @TotalOutstanding = ISNULL(SUM(TotalAmount - PaidAmount), 0.00)
    FROM Bill
    WHERE PatientID = @PatientID;

    RETURN @TotalOutstanding;
END;
GO
-- 3.3 a: Audit trigger on Patient table
-- Logs all INSERT , UPDATE , DELETE operations to a PatientAuditLog table .
-- First create the audit log table :
--CREATE TABLE PatientAuditLog (
--LogID INT IDENTITY (1 ,1) PRIMARY KEY ,
--Action NVARCHAR (10) NOT NULL ,
--PatientID INT ,
--ChangedBy NVARCHAR (100) DEFAULT SYSTEM_USER ,
--ChangedAt DATETIME2 DEFAULT SYSDATETIME () ,
--OldData NVARCHAR (MAX ),
--NewData NVARCHAR (MAX )
--);
--GO
--CREATE OR ALTER TRIGGER trg_Patient_Audit
--ON Patient
--AFTER INSERT , UPDATE , DELETE
--AS
--BEGIN
--SET NOCOUNT ON;
---- TODO : implement audit logic using INSERTED and DELETED pseudo - tables
---- Hint : use FOR JSON AUTO to serialise row data
--END ;
--GO


IF OBJECT_ID('DBO.BILLINGVIEW','V') IS NOT NULL DROP VIEW DBO.BILLINGVIEW;
GO
--Billing View
CREATE VIEW DBO.BILLINGVIEW AS
SELECT
P.PATIENTID, P.FIRSTNAME, P.LASTNAME,P.PHONE,
B.BILLID, B.ADMISSIONID,B.TOTALAMOUNT,B.PAIDAMOUNT, B.BILLDATE, B.STATUS
FROM PATIENT P
JOIN BILL B ON P.PATIENTID=B.PATIENTID
GO
--Instead of Update Trigger
CREATE OR ALTER TRIGGER TRG_BILLINGVIEW_UPDATE
ON DBO.BILLINGVIEW
INSTEAD OF UPDATE
AS
BEGIN
SET NOCOUNT ON
--Updating Patient base record
IF UPDATE(FIRSTNAME) OR UPDATE(LASTNAME) OR UPDATE (PHONE)
BEGIN
UPDATE P
SET
P.FIRSTNAME=I.FIRSTNAME,P.LASTNAME=I.LASTNAME,P.PHONE=I.PHONE
FROM PATIENT P
JOIN INSERTED I ON P.PATIENTID=I.PATIENTID;
END
END
CREATE OR ALTER TRIGGER TRG_ENFORCEAPPOINTMENTLIMIT
ON APPOINTMENT
AFTER INSERT, UPDATE
AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
SELECT 1
FROM APPOINTMENT A
WHERE A.DOCTORID IN(SELECT A.DoctorID FROM INSERTED)
AND A.APPTDATE IN (SELECT APPTDATE FROM INSERTED)
AND A.STATUS='SCHEDULED'
GROUP BY A.DOCTORID, A.APPTDATE
HAVING COUNT(*)>10
)
BEGIN
RAISERROR('BUSINESS RULE VIOLATION; A DOCTOR CANNOT BE ASSIGNED MORE THAN 10INCHES APPOINTMENTS OR A SINGLE DATE',16, 1);
ROLLBACK TRANSACTION
END
END