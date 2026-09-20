--**************************************************************************--
-- Title: Create the DWStudentEnrollments database
-- Desc: This file will drop and create the DWStudentEnrollments database. 
-- Change Log: When,Who,What
-- 2020-01-01,RRoot,Created starter code
-- 2025-12-01, SOlsen, Modified DW code
--**************************************************************************--
Set NoCount On;

USE [master]
If Exists (Select Name from SysDatabases Where Name = 'DWStudentEnrollments')
  Begin
   ALTER DATABASE DWStudentEnrollments SET SINGLE_USER WITH ROLLBACK IMMEDIATE
   DROP DATABASE DWStudentEnrollments
  End
Go
Create Database DWStudentEnrollments;
Go
USE DWStudentEnrollments;


--********************************************************************--
-- Create the Tables
--********************************************************************--
Create Table DimClasses
  ( ClassKey int Identity			Not Null
  , ClassID int						Not Null
  , ClassName nvarchar(100)			Not Null
  , ClassStartDate date				Not Null
  , ClassEndDate date				Not Null
  , CurrentClassPrice money			Not Null
  , MaxCourseEnrollment int			Not Null
  , ClassroomID int					Not Null
  , ClassroomName nvarchar(100)		Not Null
  , MaxClassroomSize int			Not Null
  , DepartmentID int				Not Null
  , DepartmentName nvarchar(100)	Not Null
  Constraint pkDimClasses Primary Key (ClassKey)
);
Go

Create Table DimStudents
  ( StudentKey int Identity				Not Null
  , StudentID int						Not Null
  , StudentFullName nvarchar(200)		Not Null
  , StudentEmail nvarchar(100)			Not Null
  Constraint pkDimStudents Primary Key (StudentKey)
);
Go

Create Table DimDates
  ( DateKey int							Not Null
  , FullDate date						Not Null
  , DateName nvarchar(50)				Not Null
  , MonthKey int						Not Null
  , MonthName nvarchar(50)				Not Null
  , QuarterKey int						Not Null
  , QuarterName nvarchar(50)			Not Null
  , YearKey int							Not Null
  , YearName nvarchar(50)				Not Null
  Constraint pkDimDates Primary Key (DateKey)
);
Go

Create Table FactEnrollments
  ( EnrollmentID int 				Not Null
  , EnrollmentDateKey int			Not Null
  , StudentKey int					Not Null
  , ClassKey int					Not Null
  , ActualEnrollmentPrice money		Not null
  Constraint pkFactEnrollments Primary Key (EnrollmentID, EnrollmentDateKey, StudentKey, ClassKey)
);
Go



--********************************************************************--
-- Create the FOREIGN KEY CONSTRAINTS
--********************************************************************--
Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimClasses
	Foreign Key (ClassKey) References DimClasses(ClassKey)

Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimStudents
	Foreign Key (StudentKey) References DimStudents(StudentKey)

Alter Table FactEnrollments
	Add Constraint fkFactEnrollmentsToDimDates
	Foreign Key (EnrollmentDateKey) References DimDates(DateKey)

--********************************************************************--
-- Create the Abstraction Layers
--********************************************************************--

-- Base Views
go
--DimClasses base view
Create or Alter View vDimClasses
AS
(Select 
	 ClassKey
	,ClassId
	,ClassName
	,ClassStartDate
	,ClassEndDate
	,CurrentClassPrice
	,MaxCourseEnrollment
From DimClasses);
Go

--DimStudents base view
Create or Alter View vDimStudents
AS
(Select 
	 StudentKey
	,StudentId
	,StudentFullName
	,StudentEmail
From DimStudents);
Go

--DimDates base view
Create or Alter View vDimDates
AS
(Select
	DateKey
  , FullDate
  , DateName
  , MonthKey
  , MonthName
  , QuarterKey
  , QuarterName
  , YearKey
  , YearName
From DimDates);
Go

--FactEnrollments base view
Create or Alter View vFactEnrollments
AS
(Select 
	EnrollmentID
  , EnrollmentDateKey
  , StudentKey
  , ClassKey
  , ActualEnrollmentPrice
 From FactEnrollments);
Go

-- Metadata View
Go
Create or Alter View vMetaDataStudentEnrollments
As
Select Top 100 Percent
 [Source Table] = DB_Name() + '.' + SCHEMA_NAME(tab.[schema_id]) + '.' + object_name(tab.[object_id])
,[Source Column] =  col.[Name]
,[Source Type] = Case 
				When t.[Name] in ('char', 'nchar', 'varchar', 'nvarchar' ) 
				  Then t.[Name] + ' (' +  format(col.max_length, '####') + ')'                
				When t.[Name]  in ('decimal', 'money') 
				  Then t.[Name] + ' (' +  format(col.[precision], '#') + ',' + format(col.scale, '#') + ')'
				 Else t.[Name] 
                End 
,[Source Nullability] = iif(col.is_nullable = 1, 'Null', 'Not Null') 
From Sys.Types as t 
Join Sys.Columns as col 
 On t.system_type_id = col.system_type_id 
Join Sys.Tables tab
  On tab.[object_id] = col.[object_id]
And t.name <> 'sysname'
Order By [Source Table], col.column_id; 
go
Select * From vMetaDataStudentEnrollments;
