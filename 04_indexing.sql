USE UniHospital ;
GO
-- Clustered index already exists ( PRIMARY KEY on each table ).
-- Create non - clustered covering indexes for common query patterns .
-- Example : covering index for appointment lookups by patient and date
--CREATE NONCLUSTERED INDEX IX_Appointment_Patient_Date
--ON Appointment ( PatientID , ApptDate )
--INCLUDE ( DoctorID , Status );
--GO
-- TODO : Design and justify indexes for the following queries :
----4.1a PATIENTS WITH ARREARS
--CREATE NONCLUSTERED INDEX IX_BILL_STATUS_FILTERED
--ON BILL (STATUS)
--INCLUDE (PATIENTID, TOTALAMOUNT, PAIDAMOUNT,BILLDATE)
--WHERE STATUS='UNPAID';
--GO
----4.1.B: ADMISSIONS CURRENTLY IN A SPECIFIC WARD 
--CREATE NONCLUSTERED INDEX IX_ADMISSION_ACTIVEWARDS_FILTERED
--ON ADMISSION(WARDID)
--INCLUDE (PATIENTID, ADMITDATE, DIAGNOSISCODE)
--WHILE DischargeDate IS NULL;
--GO
----4.1.C: PRESCRIPTIONS FOR A GIVEN ADMISSION ORDERED BY DATE
--CREATE NONCLUSTERED INDEX IX_PRESCRIPTION_ADMISSION_DATE
--ON PRESCRIPTION (ADMISSIONID, PRESCDATE)
--INCLUDE (MEDID, DOCTORID, QUANTITY);
--GO
----4.1 D: FULL-TEXT SEARCH ON APPOINTMENT NOTES (USE FULL-TEXT INEX)
--IF NOT EXISTS (SELECT * FROM SYS.FULLTEXT_CATALOGS WHERE NAME='FTC_UNIHOSPITAL')
--BEGIN
--CREATE FULLTEXT CATALOG FTC_UNIHOSPITAL AS DEFAULT;
--END
--GO

--IF NOT EXISTS (
--SELECT* FROM SYS.FULLTEXT_INDEXES
--WHERE OBJECT_ID=OBJECT_ID('APPOINTMENT')
--)
--BEGIN

--DECLARE @PKCONSTRAINTNAME NVARCHAR(128),
--SELECT TOP 1 @PKCONSTRAINTNAME =NAME FROM SYS.INDEXES
--WHERE OBJECT_ID=OBJECT_ID('APPOINTMENT') AND IS_PRIMARY_KEY=1;
--DECLARE @SQLTEMPLATE NVARCHAR(MAX)='CREATE FULLTEXT INDEX ON APPOINTMENT[NOTES]
--KEY INDEX'+ QUOTENAME(@PKCONSTRAINTNAME)+'
--ON FTC_UNIHOSPITAL
--WITH CHANGE_TRACKING AUTO;';
--EXEC SP_EXECUTESQL @SQLTEMPLATE;
--END
--GO 



--SET STATISTICS IO ON;
--SET STATISTICS TIME ON;
---- Run your query here
---- Then capture : actual execution plan ( Ctrl +M in SSMS )
---- or use sys . dm_exec_query_plan
--SELECT *
--FROM sys . dm_exec_cached_plans cp
--CROSS APPLY sys . dm_exec_sql_text (cp.plan_handle ) st
--CROSS APPLY sys . dm_exec_query_plan (cp.plan_handle ) qp
--WHERE st. text LIKE '% UniHospital %';

-- Create a non - clustered columnstore index on the Bill table
-- to accelerate aggregation queries .
--CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Bill_Analytics
--ON Bill ( BillDate , TotalAmount , PaidAmount , Status , PatientID );
--GO
---- TODO : Run the following query BEFORE and AFTER creating the index .
---- Record logical reads and elapsed time in your report .
--SELECT
--YEAR (BillDate) AS BillYear ,
--MONTH (BillDate) AS BillMonth ,
--COUNT (*) AS BillCount ,
--SUM (TotalAmount) AS TotalBilled ,
--SUM (PaidAmount) AS TotalPaid ,
--SUM (TotalAmount-PaidAmount) AS Outstanding
--FROM Bill
--GROUP BY YEAR (BillDate), MONTH (BillDate )
--ORDER BY BillYear , BillMonth ;

USE UniHospital;
GO
--Drop index if exist
IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_BILL_STATUS_FILTERED'
      AND object_id = OBJECT_ID('dbo.BILL')
)
    DROP INDEX IX_BILL_STATUS_FILTERED ON dbo.BILL;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PRESCRIPTION_ADMISSION_DATE'
      AND object_id = OBJECT_ID('dbo.PRESCRIPTION')
)
    DROP INDEX IX_PRESCRIPTION_ADMISSION_DATE ON dbo.PRESCRIPTION;
GO




