if Object_Id('dbo.DataRows') is not null
Drop Table dbo.DataRows


Create Table dbo.DataRows
(
	Id int not null,
	ADate datetime not null,
	VarCol1 varchar(max),
	VarCol2 varchar(5000),
	VarCol3 varchar(5000)
);


if Object_Id('dbo.PrintIndexStat') is not null
Drop Proc dbo.PrintIndexStat

GO

Create Proc dbo.PrintIndexStat(@PrintMessage varchar(200), @IndexId int = 0)
AS
BEGIN
		Select 
		@PrintMessage as PrintMessage,
		index_id,
		index_type_desc,
		alloc_unit_type_desc,
		page_count,
		record_count,
		forwarded_record_count
		from sys.dm_db_index_physical_stats(
		/*Database Id*/									db_id(),
		/*Object Id*/									object_id(N'dbo.DataRows'),
		/*Index Id, 0 Means HeapTable*/					@IndexId,
		/*PartitionNumber, Null is all partitions*/		NULL,
		/*Mode*/										'Detailed')
END

GO

--- No Clustered index - Means data will be in HeapTable
--- All data in the row can be contained in one page since the total size of the row < 8kb
-- The page looks as below
--- |1,1974-08-23,AAA...,AAA...,AAA...|
Insert Into dbo.DataRows(Id, ADate, VarCol1, VarCol2, VarCol3)
Values(1,'1974-08-22',REPLICATE('A',10),REPLICATE('A',10),REPLICATE('A',10))

Exec dbo.PrintIndexStat 'Only One Row'

GO

--- Second row added which almost consumes the first page. Only a few bytes left in page. 
--- All data in the row can be contained in one page since the total size of the row < 8kb
-- The page looks as below
--- |1,1974-08-23,AAA...,AAA...,AAA...|2,1974-08-23,AAA...,AAA...,AAA...|
Insert Into dbo.DataRows(Id, ADate, VarCol1, VarCol2, VarCol3)
Values(2,'1974-08-23',REPLICATE('A',10),REPLICATE('A',2010),REPLICATE('A',2000))

Exec dbo.PrintIndexStat 'Second row- First page almost done'

GO

--- Updating the first row with a bigger value. This should add another page. But also should add forward reference.
-- Means there is no space on page one to update the value inline.
-- So the value is added to the new page and the first page will get a reference to that location 
-- The page looks as below
---Page1 |1,1974-08-23,#REFERENCE->Page2,Loc1,AAA...,AAA...|2,1974-08-23,AAA...,AAA...,AAA...|
---Page2 |AAA...|
Update dbo.DataRows
Set VarCol1 = REPLICATE('A',3999)
Where Id = 1

Exec dbo.PrintIndexStat 'Updating First Row forward ref created'

GO

--- Updating the second row with a ridiculously bigger value which is bugger than a page. 
---This should move that value to LOB_DATA (Large Object) allocation unit and add refernce to it
-- The page looks as below
---Page1 |1,1974-08-23,#REFERENCE->Page2,Loc1,AAA...,AAA...|2,1974-08-23,#REFERENCE-> LOB_DATA:Page1:Loc1,AAA...,AAA...|
---Page2 |AAA...|
Update dbo.DataRows
Set VarCol1 = REPLICATE('A',32000)
Where Id = 2

Exec dbo.PrintIndexStat 'Updating second Row forward ref created'

GO

--- Updating the second row with bigger value which whill cause a page overflow 
---This should move those values to ROW_OVERFLOW_DATA allocation unit and add refernce to it
-- The page looks as below
---Page1 |1,1974-08-23,#REFERENCE->Page2,Loc1,AAA...,AAA...|2,1974-08-23,#REFERENCE-> LOB_DATA:Page1:Loc1,#REFERENCE-> ROW_OVERFLOW_DATA:Page1:Loc1,#REFERENCE-> ROW_OVERFLOW_DATA:Page1:Loc2|
---Page2 |AAA...|
Update dbo.DataRows
Set VarCol2 = REPLICATE('A',5000),
 VarCol3 = REPLICATE('A',5000)
Where Id = 2

Exec dbo.PrintIndexStat 'Updating second Row forward ref created'

GO

--- Only way to get rid of the forward ref thing is to rebuild the table
Alter Table dbo.DataRows REBUILD
Exec dbo.PrintIndexStat 'Updating second Row forward ref created'

GO


--- Create the clustered index on the table
--Now the table is clustered index and ordered.
Create Clustered Index CIX_DataRows on dbo.DataRows(Id)

Exec dbo.PrintIndexStat 'Updating second Row forward ref created', 1

GO

---No more forward refs in the B-Tree (Clustered Index or Index in general)
-- Instead does page split means a new page is added in between to accomodate the updated big data
-- All the references in the index is updated
Update dbo.DataRows
Set VarCol1 = REPLICATE('A',60000),
VarCol2 = REPLICATE('A',5000),
VarCol3 = REPLICATE('A',5000)
Where Id = 1

Exec dbo.PrintIndexStat 'Updating second Row forward ref created', 1

Go


Drop Table dbo.DataRows


/****
	SARGable predicates (Search Argumentable Predicates)
	These are the predicates which make use of Index seek instead of an Index Scan
	They are =, >, >=, <, <=, IN, BETWEEN and LIKE (Only if its 'data%' i.e prefix matching)

	Non SARGable predicates are NOT, <>, LIKE (When '%data%' non prefix matching) and NOT IN

	Also using functions on columns in predicate causes and Index Scan cause the engine has to go through every record to apply function and run predicate 

	In case of composite indexes, the Order is important and should be same as order of columns in Index
	And The leftmost arguments should be sargable which allows the SQL engine to calculate ranges
	Means if the index is on LastName and FirstName
	
	SARGable Predicates																			Non-SARGable
	LastName = 'Clark' And FirstName = 'Steve'													LastName <> 'Clark' and FirstName = 'Steve'
	LastName = 'Clark' and FirstName <> 'Steve'													LastName LIKE '%ar%' and FirstName = 'Steve'
	LastName = 'Clark'																			FirstName = 'Steve'
	LastName LIKE 'CL%'

****/