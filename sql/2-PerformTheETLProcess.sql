--**************************************************************************--
-- Title: DWStudentEnrollments ETL Process
-- Desc: This file performs ETL processing for the DWStudentEnrollments database. 
-- Change Log: When,Who,What
-- 2020-01-01,RRoot,Created starter code
-- 2025-12-03, SOlsen, Modified ETL code
--**************************************************************************--

-- ======================================================================= --
-- Using Linked Server with Staging Tables, ETL Views, and Stored Procedures
-- ======================================================================= --


Use Master;
-- Reset the linked server if it already exists
If Exists (Select * From sys.servers Where name = N'AzureLinkedServerName')
Begin
  Exec master.dbo.sp_dropserver 
    @server = N'AzureLinkedServerName', 
    @droplogins = 'droplogins';
End
Go

-- Create a Linked Server to the Azure SQL Database
Exec master.dbo.sp_addlinkedserver 
    @server   = N'AzureLinkedServerName',  -- A name you choose for the linked server
    @srvproduct = N'',
    @provider = N'MSOLEDBSQL',             -- Use the modern OLE DB driver
    @datasrc  = N'<your-server>.database.windows.net', -- Your Azure server name
    @catalog  = N'StudentEnrollments';     -- The specific database name
Go

-- Configure credentials for the linked server
Exec master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'AzureLinkedServerName', 
    @useself    = N'FALSE', 
    @rmtuser    = N'<your-azure-login>',   -- Your Azure SQL login name (Change this to your login)
    @rmtpassword= N'<your-azure-password>';    -- Your Azure SQL password (Change this to your password)
Go


-- Let's verify that we can read data from the Azure database using the linked server
--Select * From AzureLinkedServerName.StudentEnrollments.dbo.Students; -- Verify current data

go

USE DWStudentEnrollments;
Go
Set NoCount On;
Go


--********************************************************************--
-- 0) Create ETL metadata objects
--********************************************************************--
If NOT Exists(Select * From Sys.tables where Name = 'EtlLog')
  Create -- Drop
  Table EtlLog
  (EtlLogID int identity Primary Key
  ,ETLDateAndTime datetime Default GetDate()
  ,ETLAction varchar(100)
  ,EtlLogMessage varchar(2000)
  );
go

Create or Alter View vEtlLog
As
  Select
   EtlLogID
  ,ETLDate = Format(ETLDateAndTime, 'D', 'en-us')
  ,ETLTime = Format(Cast(ETLDateAndTime as datetime2), 'HH:mm:ss', 'en-us')
  ,ETLAction
  ,EtlLogMessage
  From EtlLog;
go


Create or Alter Proc pInsEtlLog
 (@ETLAction varchar(100), @EtlLogMessage varchar(2000))
--*************************************************************************--
-- Desc:This Sproc creates an admin table for logging ETL metadata. 
-- Change Log: When,Who,What
-- 2020-01-01,RRoot,Created Sproc
--*************************************************************************--
As
Begin
  Declare @RC int = 0;
  Begin Try
    Begin Tran;
      Insert Into EtlLog
       (ETLAction,EtlLogMessage)
      Values
       (@ETLAction,@EtlLogMessage)
    Commit Tran;
    Set @RC = 1;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback Tran;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go
-- Truncate Table ETLLog;
-- Exec pInsETLLog @ETLAction = 'Begin ETL',@ETLLogMessage = 'Start of ETL process' 
-- Select * From vEtlLog

--********************************************************************--
-- Pre-load tasks
--********************************************************************--

--Drop Foreign Keys
Go
Create Or Alter Proc pETLDropFks

As 
Begin
  Declare @RC int = 0;
  Begin Try
	  Alter Table FactEnrollments Drop Constraint fkFactEnrollmentsToDimClasses;
	  Alter Table FactEnrollments Drop Constraint fkFactEnrollmentsToDimStudents;
	  Alter Table FactEnrollments Drop Constraint fkFactEnrollmentsToDimDates;

	  Exec pInsETLLog
	        @ETLAction = 'pETLDropFks'
	       ,@ETLLogMessage = 'Dropped Foreign Keys';
    Set @RC = 1;
  End Try
  Begin Catch
    Declare @ErrorMessage nvarchar(1000) = Error_Message()
	  Exec pInsETLLog 
	      @ETLAction = 'pETLDropFks'
	     ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--Truncate Tables
Go
Create Or Alter Proc pETLTruncateTables

As 
Begin
	Declare @RC int = 0;
  Begin Try
	  Truncate Table FactEnrollments;
	  Truncate Table DimClasses;
	  Truncate Table DimStudents;
	  Truncate Table DimDates;

	  Exec pInsETLLog
	        @ETLAction = 'pETLTruncateTables'
	       ,@ETLLogMessage = 'Truncated Tables';
    Set @RC = 1;
  End Try
  Begin Catch
    Declare @ErrorMessage nvarchar(1000) = Error_Message()
	  Exec pInsETLLog 
	        @ETLAction = 'pETLTruncateTables'
	       ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go


-- Exec pEtlDropFks; Select * From vEtlLog;
-- Exec pEtlTruncateTables; Select * From vEtlLog;

--********************************************************************--
-- Load dimension tables
--********************************************************************--
-- DimDates should go first due to the lookups in other tables
Go
Create or Alter Proc pEtlDimDates
As 
Begin
  Declare @RC int = 1;
  Declare @Message varchar(1000) 
  Set NoCount On; -- This will remove the 1 row affected msg in the While loop;
  Begin Try
 	  -- Create variables to hold the start and end date
	  Declare @StartDate datetime = '01/01/2019';
	  Declare @EndDate datetime = '12/31/2029'; 
	  Declare @DateInProcess datetime;
      Declare @TotalRows int = 0;

	  -- Use a while loop to add dates to the table
	  Set @DateInProcess = @StartDate;

	  While @DateInProcess <= @EndDate
	    Begin
	      -- Add a row into the date dimensiOn table for this date
	     Begin Tran;
	       Insert Into DimDates 
	       ( [DateKey], [FullDate], [DateName], [MonthKey], [MonthName], [QuarterKey], [QuarterName], [YearKey], [YearName] )
	       Values ( 
	   	     Cast(Convert(nvarchar(50), @DateInProcess , 112) as int) -- [DateKey]
	        ,@DateInProcess -- [FullDate]
	        ,DateName( weekday, @DateInProcess ) + ', ' + Convert(nvarchar(50), @DateInProcess , 110) -- [USADateName]  
	        ,Left(Cast(Convert(nvarchar(50), @DateInProcess , 112) as int), 6) -- [MonthKey]   
	        ,DateName( MONTH, @DateInProcess ) + ', ' + Cast( Year(@DateInProcess ) as nVarchar(50) ) -- [MonthName]
	        , Cast(Cast(YEAR(@DateInProcess) as nvarchar(50))  + '0' + DateName( QUARTER,  @DateInProcess) as int) -- [QuarterKey]
	        ,'Q' + DateName( QUARTER, @DateInProcess ) + ', ' + Cast( Year(@DateInProcess) as nVarchar(50) ) -- [QuarterName] 
	        ,Year( @DateInProcess ) -- [YearKey]
	        ,Cast( Year(@DateInProcess ) as nVarchar(50) ) -- [YearName] 
	        ); 
	       -- Add a day and loop again
	       Set @DateInProcess = DateAdd(d, 1, @DateInProcess);
	     Commit Tran;
      Set @TotalRows += 1;
	  End -- While
    
	-- 2e) Add additional lookup values to DimDates
	 Begin Tran;
	 Insert Into DimDates 
	   ( [DateKey]
	   , [FullDate]
	   , [DateName]
	   , [MonthKey]
	   , [MonthName]
	   , [QuarterKey]
	   , [QuarterName]
	   , [YearKey]
	   , [YearName] )
	   Select 
		 [DateKey] = -1
	   , [FullDate] = '19000101'
	   , [DateName] = Cast('Unknown Day' as nVarchar(50) )
	   , [MonthKey] = -1
	   , [MonthName] = Cast('Unknown Month' as nVarchar(50) )
	   , [QuarterKey] =  -1
	   , [QuarterName] = Cast('Unknown Quarter' as nVarchar(50) )
	   , [YearKey] = -1
	   , [YearName] = Cast('Unknown Year' as nVarchar(50) )
	   Union
	   Select 
		 [DateKey] = -2
	   , [FullDate] = '19000102'
	   , [DateName] = Cast('Corrupt Day' as nVarchar(50) )
	   , [MonthKey] = -2
	   , [MonthName] = Cast('Corrupt Month' as nVarchar(50) )
	   , [QuarterKey] =  -2
	   , [QuarterName] = Cast('Corrupt Quarter' as nVarchar(50) )
	   , [YearKey] = -2
	   , [YearName] = Cast('Corrupt Year' as nVarchar(50) );
	  Commit Tran;
    Set @TotalRows += 2;

	Set @Message = 'Filled DimDates (' + Cast(@TotalRows as varchar(100)) + ' rows)';
	Exec pInsEtlLog
	     @ETLAction = 'pEtlDimDates'
	    ,@EtlLogMessage = @Message;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback Tran;
    Declare @ErrorMessage nvarchar(1000) = Error_Message();
	  Exec pInsEtlLog
	        @ETLAction = 'pEtlDimDates'
	       ,@EtlLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Set NoCount Off;
  Return @RC;
End
Go
-- Exec pEtlDimDates; Select * From DimDates;Select * From vEtlLog;



/*******dbo.DimStudents******/

Create or Alter View vETLDimStudents
As
  Select
     [StudentId]   = s.Id
    ,[StudentFullName] = Cast((s.FirstName + ' ' + s.LastName) as nVarChar(200))
    ,[StudentEmail]= s.Email
  From AzureLinkedServerName.StudentEnrollments.dbo.Students As s;
Go

Create Or Alter Proc pETLDimStudents
As 
Begin 
	Declare @RC int = 0;
	Declare @Message varchar(1000) 
  Begin Try
	  Begin Tran;
		Insert Into DimStudents 
	   (StudentID,StudentFullName, StudentEmail)
	   Select 
		 [StudentID]
		,[StudentFullName]
		,[StudentEmail]
		From vETLDimStudents
	    Set @Message = 'Filled DimStudents (' + Cast(@@RowCount as varchar(100)) + ' rows)';
	  Commit Tran;
	  Exec pInsETLLog
 	       @ETLAction = 'pETLDimStudents'
 	      ,@ETLLogMessage = @Message;
    Set @RC = 1;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback;
    Declare @ErrorMessage nvarchar(1000) = Error_Message();
    Exec pInsETLLog 
         @ETLAction = 'pETLDimStudents'
        ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--Exec pETLDimStudents; Select * From DimStudents; Select * From ETLLog;

/*******dbo.DimClasses******/

Create or Alter View vETLDimClasses
As
  Select
     [ClassId]   = c.[Id]
    ,[ClassName] = IsNULL(c.[Name], 'Undecided')
	,[DepartmentID] = IsNULL(d.[Id], -1)
	,[DepartmentName]= IsNULL(d.[Name], 'Undecided')
	,[ClassStartDate] = IsNULL(CAST(c.StartDate as date), '1900-01-01')
	,[ClassEndDate] = IsNULL(CAST(c.EndDate as date), '1900-01-02')
	,[CurrentClassPrice] = IsNULL(c.[Price], -1)
	,[MaxCourseEnrollment] = IsNULL(c.[MaxSize], -1)
	,[ClassroomID] = IsNULL(cr.[Id], -1)
	,[ClassroomName] = IsNULL(cr.[Name], 'Undecided')
	,[MaxClassroomSize] = cr.[MaxSize]
  From AzureLinkedServerName.StudentEnrollments.dbo.Classes As c
  Full Join AzureLinkedServerName.StudentEnrollments.dbo.Classrooms As cr
	On c.ClassroomId = cr.Id
  Full Join AzureLinkedServerName.StudentEnrollments.dbo.Departments As d
	On c.DepartmentId = d.Id;
Go

Create Or Alter Proc pETLDimClasses
As 
Begin 
	Declare @RC int = 0;
	Declare @Message varchar(1000) 
  Begin Try
	  Begin Tran;
		Insert Into DimClasses 
	   (ClassID,ClassName, ClassStartDate, ClassEndDate, CurrentClassPrice, MaxCourseEnrollment, ClassroomID
	   , ClassroomName, MaxClassroomSize, DepartmentID, DepartmentName)
	   Select 
		 [ClassID]
		,[ClassName]
		,[ClassStartDate]
		,[ClassEndDate]
		,[CurrentClassPrice]
		,[MaxCourseEnrollment]
		,[ClassroomID]
		,[ClassroomName]
		,[MaxClassroomSize]
		,[DepartmentID]
		,[DepartmentName]
		From vETLDimClasses
	    Set @Message = 'Filled DimClasses (' + Cast(@@RowCount as varchar(100)) + ' rows)';
	  Commit Tran;
	  Exec pInsETLLog
 	       @ETLAction = 'pETLDimClasses'
 	      ,@ETLLogMessage = @Message;
    Set @RC = 1;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback;
    Declare @ErrorMessage nvarchar(1000) = Error_Message();
    Exec pInsETLLog 
         @ETLAction = 'pETLDimClasses'
        ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--Exec pETLDimClasses; Select * From DimClasses; Select * From ETLLog;

--********************************************************************--
-- Load Fact Tables
--********************************************************************--
/***dbo.FactEnrollments***/

Create or Alter View vETLFactEnrollments
As
  Select
     [EnrollmentId]   = e.[Id]
	,[EnrollmentDate] = Cast(e.[Date] as date)
    ,[EnrollmentDateKey] = dd.[DateKey]
	,[StudentID] = e.[StudentID]
    ,[StudentKey]= ds.[StudentKey]
	,[ClassID] = e.[ClassID]
	,[ClassKey] = dc.[ClassKey]
	,[ActualEnrollmentPrice] = e.Price
  From AzureLinkedServerName.StudentEnrollments.dbo.Enrollments as e
  Inner Join DWStudentEnrollments.dbo.DimDates as dd
	On Cast(e.[Date] as date) = dd.FullDate
  Inner Join DWStudentEnrollments.dbo.DimStudents as ds
	On e.[StudentId] = ds.[StudentID]
  Inner Join DWStudentEnrollments.dbo.DimClasses as dc
	On e.[ClassId] = dc.[ClassID]
Go


Create Or Alter Proc pETLFactEnrollments
As 
Begin 
	Declare @RC int = 0;
	Declare @Message varchar(1000) 
  Begin Try
	  Begin Tran;
		Insert Into FactEnrollments 
	   (EnrollmentID, EnrollmentDateKey, StudentKey, ClassKey, ActualEnrollmentPrice)
	   Select 
		 [EnrollmentID]
		,[EnrollmentDateKey]
		,[StudentKey]
		,[ClassKey]
		,[ActualEnrollmentPrice]
		From vETLFactEnrollments
	    Set @Message = 'Filled FactEnrollments (' + Cast(@@RowCount as varchar(100)) + ' rows)';
	  Commit Tran;
	  Exec pInsETLLog
 	       @ETLAction = 'pETLFactEnrollments'
 	      ,@ETLLogMessage = @Message;
    Set @RC = 1;
  End Try
  Begin Catch
    If @@TRANCOUNT > 0 Rollback;
    Declare @ErrorMessage nvarchar(1000) = Error_Message();
    Exec pInsETLLog 
         @ETLAction = 'pETLFactEnrollments'
        ,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--Exec pETLFactEnrollments; Select * From FactEnrollments; Select * From ETLLog;

--********************************************************************--
-- Post-load Tasks
--********************************************************************--
-- Re-Create the Foreign Key Constraints
--********************************************************************--

Go
Create Or Alter Proc pETLReplaceFks

As 
Begin
  Declare @RC int = 0;
  Begin Try

  Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimClasses
	Foreign Key (ClassKey) References DimClasses(ClassKey);

  Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimStudents
	Foreign Key (StudentKey) References DimStudents(StudentKey);

  Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimDates
	Foreign Key (EnrollmentDateKey) References DimDates(DateKey);

	Exec pInsETLLog
		 @ETLAction = 'pETLReplaceFks'
		,@ETLLogMessage = 'Replaced Foreign Keys';
  Set @RC = 1;
  End Try
  Begin Catch
	Declare @ErrorMessage nvarchar(1000) = Error_Message()
		Exec pInsETLLog
			 @ETLAction = 'pETLReplaceFks'
			,@ETLLogMessage = @ErrorMessage;
    Set @RC = -1;
  End Catch
  Return @RC;
End
Go

--********************************************************************--
-- Review the results of this script
--********************************************************************--
Go
Exec pInsETLLog @ETLAction = 'Begin ETL', @ETLLogMessage = 'Start of ETL process' 
Exec pEtlDropFks; 
Exec pEtlTruncateTables;
Exec pEtlDimDates; Select top 10 * From DimDates;
Exec pEtlDimClasses; Select * From DimClasses;
Exec pEtlDimStudents; Select * From DimStudents;
Exec pEtlFactEnrollments; Select * From FactEnrollments;
Exec pEtlReplaceFKs;
Exec pInsETLLog @ETLAction = 'End ETL', @ETLLogMessage = 'End of ETL process' 
Select * From vEtlLog



