--USE UniHospital ;
--GO
---- Scenario : transfer a patient from one ward to another atomically .
---- Steps : (1) discharge from current ward , (2) admit to new ward ,
---- (3) create a transfer log entry .
---- All three steps must succeed or all must roll back .

USE UniHospital;
GO
DECLARE @PatientID INT = 1, @NewWardID INT = 2, @DiagnosisCode NVARCHAR(20) = '110';
BEGIN TRY
    BEGIN TRANSACTION TransferPatient;
    -- Discharge from current ward
    UPDATE Admission
    SET DischargeDate = CAST(GETDATE() AS DATE)
    WHERE PatientID = @PatientID AND DischargeDate IS NULL;
    IF @@ROWCOUNT = 0
    THROW 50010, 'No active admission found for patient.', 1;
    -- Creating new admission record
    DECLARE @Capacity INT, @CurrentOcc INT;
    SELECT @Capacity = Capacity FROM Ward WHERE WardID = @NewWardID;
    SELECT @CurrentOcc = COUNT(*) FROM Admission WHERE WardID = @NewWardID AND DischargeDate IS NULL;

    IF @CurrentOcc >= @Capacity
        THROW 50011, 'Target ward is full.', 1;

  INSERT INTO Admission (PatientID, WardID, AdmitDate, DischargeDate, DiagnosisCode)
  VALUES (@PatientID, @NewWardID, CAST(GETDATE() AS DATE), NULL, @DiagnosisCode);
--LOG TRANSFER TRACE

IF OBJECT_ID('DBO.TRANSFERLOG,U') IS NULL
BEGIN
CREATE TABLE DBO.TRANSFERLOG(
LOGID INT IDENTITY (1,1)PRIMARY KEY,
PATIENTID INT,
TRNSFERDATE DATETIME DEFAULT GETDATE(),
DETAILS NVARCHAR(250)
)
END
INSERT INTO DBO.TRANSFERLOG (PATIENTID, DETAILS)
VALUES (@PATIENTID, CONCAT('Transfered to WARD ID', @NEWWARDID));

COMMIT TRANSACTION TransferPatient;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION TransferPatient;

SELECT
ERROR_NUMBER()AS ERRORNUMBER,ERROR_SEVERITY()AS SEVERITY,
ERROR_STATE()AS STATE,ERROR_MESSAGE()AS MESSAGE;
END CATCH
GO


