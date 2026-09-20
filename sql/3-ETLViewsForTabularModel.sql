/****************
 Title:   DWStudentEnrollments ETL Views for Tabular Model
 Author: SOlsen
 Desc: This file creates [DWStudentEnrollments] ETL Views for Tabular Model. 
 Change Log: When,Who,What
 2020-01-01,RRoot,Created File
 2025-12-07,SOlsen, Modified ETL code
 *****************/

USE DWStudentEnrollments;
Go
Set NoCount On;
Go


-- Create the DimDates view
Go
Create or Alter View vTabularETLDimDates
AS
  Select 
	 [DateKey] = Convert(date, Cast([DateKey] as char(8)), 110)
	,[FullDate]
	,[DateName]
	,[MonthKey]
	,[MonthName]
	,[QuarterKey]
	,[QuarterName]
	,[YearKey]
	,[YearName]
  From DimDates
  Where DateKey Not In (-1,-2)
Go
-- Check the view: Select * From vTabularETLDimDates


-- Create the DimStudents view
Go
Create or Alter View vTabularETLDimStudents
AS
  Select 
   [StudentKey]
  ,[StudentID]
  ,[StudentFullName]
  ,[StudentEmail]
  From DimStudents;
Go
-- Check the view: Select * From vTabularETLDimStudents


-- Create the DimClasses view
Create or Alter View vTabularETLDimClasses
AS
  Select
   [ClassKey]  
  ,[ClassID]
  ,[ClassName]
  ,[DepartmentID]
  ,[DepartmentName]
  ,[ClassStartDate]
  ,[ClassEndDate]
  ,[CurrentClassPrice]
  ,[MaxCourseEnrollment]
  ,[ClassroomID]
  ,[ClassroomName]
  ,[MaxClassroomSize]
  From DimClasses
Go
-- Check the view: Select * From vTabularETLDimClasses


-- Create the FactEnrollments view
Create or Alter View vTabularETLFactEnrollments
AS
  Select 
   [EnrollmentID]
  ,[EnrollmentDateKey] = Convert(date, Cast([EnrollmentDateKey] as char(8)), 110)
  ,[StudentKey]
  ,[ClassKey]
  ,[ActualEnrollmentPrice]
  From FactEnrollments
Go
-- Check the view: Select * From vTabularETLFactEnrollments



Select * From vTabularETLDimDates;
Select * From vTabularETLDimClasses;
Select * From vTabularETLDimStudents;
Select * From vTabularETLFactEnrollments;