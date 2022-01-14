/*
	ERROR HANDLING

	SQL does error handling in wierd ways.

*/

-- Data Set up
If OBJECT_ID('dbo.Orders') is not null
Drop Table dbo.Orders

If OBJECT_ID('dbo.Customer') is not null
Drop Table dbo.Customer

Create table dbo.Customer (Id int, Primary Key(Id))

Create Table dbo.Orders(OrderId int, CustomerId int, Constraint FK_Order_Customer FOREIGN KEY(CustomerId) REFERENCES Customer(Id))



If OBJECT_ID('dbo.ResetData') is not null
Drop PROC dbo.ResetData

GO

Create Proc dbo.ResetData
AS
BEGIN
	Delete from Orders
	Delete from Customer

	Insert Into Customer
	Select 1 Union
	Select 2 Union
	Select 3

	Insert Into Orders
	Values(2,2)
END

GO

-- Trying to delete Customer will cause foriegn key violation if you try to delete customer 2 
Exec ResetData
SET XACT_ABORT OFF

delete from Customer where Id = 1
delete from Customer where Id = 2
delete from Customer where Id = 3

Select * from Customer

Select @@TRANCOUNT, XACT_STATE()

-- The result shows Customer 1 and 3 deleted. 
-- That means even if the second statement errored out the third statement was executed which is wierd
GO

-- Try catch has same behaviour
Exec ResetData
SET XACT_ABORT OFF


BEGIN TRY
	delete from Customer where Id = 1
	delete from Customer where Id = 2
	delete from Customer where Id = 3
END TRY
BEGIN CATCH
	Select @@TRANCOUNT, XACT_STATE()
	Select ERROR_MESSAGE()
END CATCH
Select * from Customer

-- Here the execution stops at the error and behaves as expected
GO

-- Setting XACT_ABORT

Exec ResetData
SET XACT_ABORT ON
delete from Customer where Id = 1
delete from Customer where Id = 2
delete from Customer where Id = 3
Select @@TRANCOUNT, XACT_STATE()
Select ERROR_MESSAGE()
Select * from Customer

-- If you set XACT_ABORT then it acts as TRY catch block
--The execution stops at the error
GO

-- Setting Explicit Transactions
Exec ResetData
SET XACT_ABORT OFF

BEGIN TRY
	BEGIN TRAN
		delete from Customer where Id = 1
		delete from Customer where Id = 2
		delete from Customer where Id = 3
	COMMIT
END TRY
BEGIN CATCH
	Select @@TRANCOUNT, XACT_STATE()
	Select ERROR_MESSAGE()
	if @@TRANCOUNT > 0
		ROLLBACK
END CATCH
Select * from Customer

-- None of the statement committed in the batch which is what we want. Its the atomicity principle
GO

-- Setting Nested Transactions
Exec ResetData
SET XACT_ABORT OFF

BEGIN TRY
	BEGIN TRAN
		BEGIN TRAN
			delete from Customer where Id = 1
		Commit
		BEGIN TRAN
			delete from Customer where Id = 2
			delete from Customer where Id = 3
		COMMIT
	COMMIT
END TRY
BEGIN CATCH
	Select 'Before Rollback',@@TRANCOUNT trancount, XACT_STATE() xactState
	Select ERROR_MESSAGE()
	if @@TRANCOUNT > 0
	BEGIN
		SELECT 'ROLLBACK'
		ROLLBACK
		Select 'After Rollback', @@TRANCOUNT trancount, XACT_STATE() xactState
	END
END CATCH
Select * from Customer

-- None of the statement committed in the batch which is what we want.
--Even though we tried to commit the first statement the ROLLBACK rolled back everything under the parent transaction
GO


-- uncommitable Transactions by setting XACT_ABORT ON.
-- Trying to commit an uncommitable transaction
-- This will fail since the transaction is uncommitable and can only be rolled back
-- This also rollsback the uncommitable transaction automatically
Exec ResetData
SET XACT_ABORT OFF

BEGIN TRY
	SET XACT_ABORT ON
	BEGIN TRAN
		delete from Customer where Id = 1
		delete from Customer where Id = 2
		delete from Customer where Id = 3
	COMMIT
END TRY
BEGIN CATCH
	Select 'Before Rollback',@@TRANCOUNT trancount, XACT_STATE() xactState
	Select ERROR_MESSAGE()
	if @@TRANCOUNT > 0
	BEGIN
		SELECT 'ROLLBACK'
		COMMIT --  Will fail here coz the XACT_STATE is -1 it can only be rolled back not committed
	END
END CATCH
Select 'After Rollback', @@TRANCOUNT trancount, XACT_STATE() xactState
-- At this point the transaction will be automatically rolled back

GO
Select * from Customer

-- Setting the XACT_ABORT option gives you XACT_STATE as -1
-- ** XACT_STATE 1 means active commitable transation pending, -1 means active non commitable transaction , 0 means no temprature
GO


/*
	Ideal way to error handle
	1) Always use explicit transactions. This gurantees do or die situation for batch. Also its efficient IO - wise due to write ahead logs that auto commit transactions
	2) Set XACT_ABORT to on before starting transaction. This forces SQL to not ignore the error based on severity and prevents user from commiting failed transaction
	3) Always explicitly rollback in case of errors

*/


