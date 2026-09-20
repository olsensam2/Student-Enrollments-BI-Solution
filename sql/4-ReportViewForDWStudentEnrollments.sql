-- Title:   DWStudentEnrollments ETL Views for DocumentDB
-- Author: RRoot
-- Desc: This file creates [DWStudentEnrollments] Reporting Functions and Views for DWStudentEnrollment. 
-- Change Log: When,Who,What
-- 2020-01-01,RRoot,Created File
-- 2025-12-02,SOlsen, Modified ETL code
--**************************************************************************--

USE DWStudentEnrollments;
Go

Create or Alter View vRptStudentEnrollments
AS
  Select 
   [EnrollmentID] = EnrollmentID 
  ,[FullDate] = Cast(FullDate as Date)
  ,[Date] =[DateName]
  ,[Month] = [MonthName]
  ,[Quarter] = QuarterName
  ,[Year] = YearName
  ,[ClassID] = ClassID
  ,[Course] = ClassName
  ,[DepartmentID] = DepartmentID
  ,[Department]= DepartmentName
  ,[ClassStartDate] = ClassStartDate
  ,[ClassEndDate] = ClassEndDate
  ,[CurrentCoursePrice] = CurrentClassPrice
  ,[MaxCourseEnrollment] = MaxCourseEnrollment
  ,[ClassroomID] = ClassroomID
  ,[Classroom] = ClassroomName
  ,[MaxClassroomSize] = MaxClassroomSize
  ,[StudentID] = StudentID
  ,[StudentFullName] = StudentFullName
  ,[StudentEmail] = StudentEmail
  ,[EnrollmentsPerCourse] = Count(fe.Studentkey) Over(Partition By fe.ClassKey)
  ,[ActualEnrollmentPrice] = fe.ActualEnrollmentPrice
  From FactEnrollments as fe
  Join DimDates as dd
    On fe.EnrollmentDateKey = dd.DateKey
  Join DimClasses as dc
    On fe.ClassKey = dc.ClassKey
  Join DimStudents as ds
    On fe.StudentKey = ds.StudentKey;
Go
Select * From vRptStudentEnrollments;
