--*************************************************************************--
-- Title: Create the StudentEnrollments database
-- Desc: Drops and create the StudentEnrollments database
-- Change Log: When,Who,What
-- 2022-11-16,RRoot,Created File
--**************************************************************************--
Set NoCount On;


--NOTE: You only need this code to create a local installation of the database. 
--Using it only if you cannot create one in the Azure cloud. 

  USE [master]
  If Exists (Select Name from SysDatabases Where Name = 'StudentEnrollments')
    Begin
     Alter Database StudentEnrollments set single_user with rollback immediate
     Drop Database StudentEnrollments
    End
  Go
  Create Database StudentEnrollments;
  Go
  USE StudentEnrollments;




--********************************************************************--
-- Create the Tables
--********************************************************************--
Create Table Students 
  ( Id int Not Null Identity Constraint pkStudents Primary Key
  , FirstName nvarchar(40) Not Null
  , LastName nvarchar(50) Not Null
  , Email nvarchar(100) Not Null
);
Go

Create Table Classes 
  ( Id int Not Null Identity Constraint pkDimClasses Primary Key 
  , [Name] nvarchar(60) Not Null
  , StartDate datetime Not Null
  , EndDate datetime Not Null
  , Price money Not Null
  , MaxSize int Not Null
  , ClassroomId int Not Null
  , DepartmentId int Not Null 
 );
Go
Create Table Classrooms 
  ( Id int Not Null Identity Constraint pkClassrooms Primary Key 
  , [Name] nvarchar(70) Not Null 
  , MaxSize int Not Null
);
Go
Create Table Departments 
  ( Id int Not Null Identity Constraint pkDepartments Primary Key 
  , [Name] nvarchar(50) Not Null 
);
Go

-- Fact Table --
Create Table Enrollments
  ( Id int Not Null Identity Constraint pkEnrollments Primary Key 
  , [Date] datetime Not Null
  , StudentId int Not Null
  , ClassId int Not Null
  , Price money Not Null
);
Go

--********************************************************************--
-- Create the Foreign Key constraints
--********************************************************************--
-- Enrollments --
Alter Table Enrollments Add Constraint fkEnrollmentsToStudents
  Foreign Key([StudentId]) References Students(Id);
Alter Table Enrollments Add Constraint fkEnrollmentsToClasses
  Foreign Key([ClassId]) References Classes(Id);
Go
-- Classes --
Alter Table Classes Add Constraint fkClassesToClassrooms
  Foreign Key([ClassroomId]) References Classrooms(Id);
Alter Table Classes Add Constraint fkClassesToDepartments
  Foreign Key([DepartmentId]) References Departments(Id);
Go

--********************************************************************--
-- Add test data
--********************************************************************--
Insert Into Departments
(Name)
Values
('Tech');
go
Insert Into Classrooms
(Name, MaxSize)
Values
('RoomA',35),
('RoomB',50);
go
Insert Into Students 
(FirstName, LastName, Email) 
Values 
('Bob', 'Smith', 'BSmith@gomail.com'),
('Sue', 'Jones', 'SJones@gomail.com');
go
Insert Into Classes 
(Name, StartDate, EndDate, Price, MaxSize, ClassroomId, DepartmentId)
Values
('SQL1','1/4/2020','1/18/2020',999.99,32,1,1),
('SQL2','2/1/2020','2/15/2020',999.99,32,2,1);
go
Insert Into Enrollments
(Date, StudentId, ClassId, Price)
Values
('2019-12-18 16:59:29',1,1,899.99),
('2019-12-18 16:59:29',1,2,899.99),
('2020-01-15 12:46:23',2,2,999.99);
go

--********************************************************************--
-- Review the results of this script
--**
Select  
  SourceObjectName = TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME
, DataType = DATA_TYPE + IIF(CHARACTER_MAXIMUM_LENGTH is Null, '' , '(' + Cast(CHARACTER_MAXIMUM_LENGTH as varchar(10)) + ')')
, Nullable = IS_NULLABLE
From INFORMATION_SCHEMA.COLUMNS
go

Select * From Departments;
Select * From Classrooms;
Select * From Classes;
Select * From Students;
Select * From Enrollments;
