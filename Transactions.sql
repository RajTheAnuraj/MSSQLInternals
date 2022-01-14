/*
Everything in SQL is ran under transactions. If not implicitly specified by BEGIN tran SQL uses auto committed transactions
** Autocommitted transactions are one per statement. That is a transaction is started for each statement rather than a batch.

This is not good for multiple reasons

1) Since SQL uses write ahead logs for durability, it writes the log into transaction log before the commit is executed.
In autocommitted, this write is done for every single statement. This causes unecessary IO access and cpu cycles

In Explicit transactions, SQL store the logs into a memory buffer and only writes to  once commit is called. (60KB size)
This means in case of disaster a small number of records are lost but reduces the contention and user has control on when to commit

2) The previous statement will be committed even if the next one fails. In explicit the commit works for a whole batch and rollback also works for whole batch

** SQL 2014 and up can enable delayed durability to delay flushing log records on commit.
*/

if Object_Id('dbo.TransactionOverhead') is not NULL
drop table dbo.TransactionOverhead

Create Table dbo.TransactionOverhead
(
	Id int not null,
	Letter char(1),
	Primary Key clustered(Id)
)
GO

-- Autocommitted transactions
declare @Id int =1, @StartTime datetime = getdate(), @num_of_writes bigint, @num_of_bytes_written bigint

Select @num_of_writes = num_of_writes, @num_of_bytes_written = num_of_bytes_written
From sys.dm_io_virtual_file_stats(db_id(),2)

while(@Id < 10000)
BEGIN
	Insert into TransactionOverhead
	values(@Id,'A')

	Update TransactionOverhead
	Set Letter = 'B'
	Where Id = @Id

	Delete From TransactionOverhead
	Where Id = @Id

	SET @Id = @Id +1
END

Select DATEDIFF(MILLISECOND, @StartTime, GetDate()) MilliSecsTaken, num_of_writes - @num_of_writes num_of_writes, num_of_bytes_written - @num_of_bytes_written num_of_bytes_written
From sys.dm_io_virtual_file_stats(db_id(),2)
/*
MilliSecsTaken	num_of_writes	num_of_bytes_written
9740			30,000			16,044,032
*/
GO

-- Explicit transactions
declare @Id int =1, @StartTime datetime = getdate(), @num_of_writes bigint, @num_of_bytes_written bigint

Select @num_of_writes = num_of_writes, @num_of_bytes_written = num_of_bytes_written
From sys.dm_io_virtual_file_stats(db_id(),2)

while(@Id < 10000)
BEGIN
	BEGIN TRAN
		Insert into TransactionOverhead
		values(@Id,'A')

		Update TransactionOverhead
		Set Letter = 'B'
		Where Id = @Id

		Delete From TransactionOverhead
		Where Id = @Id
	COMMIT TRAN
	SET @Id = @Id +1
END

Select DATEDIFF(MILLISECOND, @StartTime, GetDate()) MilliSecsTaken, num_of_writes - @num_of_writes num_of_writes, num_of_bytes_written - @num_of_bytes_written num_of_bytes_written
From sys.dm_io_virtual_file_stats(db_id(),2)

/*
MilliSecsTaken	num_of_writes	num_of_bytes_written
4353			9,999			10,929,664
*/
GO


