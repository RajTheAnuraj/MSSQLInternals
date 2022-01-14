/*
	Transaction isolation levels handle two aspects
	1) Read data consistency
	2) Blocking

	Note : The transaction isolation levels is mainly about reader. The writer will acquire the exclusive and update locks regardless of the isolation levels

	1)Read data Consistency
		a) Dirty Read -  The data is read before its committed. The transaction can be rolled back which leads to inconsistency.
		b) Non Repeatable Reads - Multiple reads returns different results. This might be because another session is Updating or deleting records while the records are read
		c) Phantom Records - Multiple reads may return new records. This might be because another session is inserting data

	2) Blocking
		a) Pessimistic blocking - The assumption that multiple session may and will try to update and overwrite each others data. SQL server uses locks to prevent this issue. 
		   This could slow down things, since the lock has to be released by one transaction for other to access or even read it.
		b) Optimistic blocking - Even though multiple session are changing data, the chances of over-writing is low. So no locking is involved. A snapshot copy of data is created and worked on
		   This could lead to write - write issue when multiple transaction change the same records. Only one record will be committed and second transacion will fail.
		   The write-write conflict error should be handled while using this type of blocking

SQL Supports 6 levels of Transaction Isolation

Isolation Level				Type					Dirty Read	Non-Repeatable Reads	Phantom Records		Write-Write Conflict
---------------------------|-----------------------|------------|-----------------------|------------------|--------------------
READ UNCOMMITTED			Pessimistic				YES			YES						YES					NO
READ COMMITTED				Pessimistic				NO			YES						YES					NO
REPEATABLE READ				Pessimistic				NO			NO						YES					NO
SERIALIZABLE				Pessimistic				NO			NO						NO					NO
READ COMMITTED SNAPSHOT		Pessimistic for reader	NO			YES						YES					NO
							Optimistic for writer
SNAPSHOT					Optimistic				NO			NO						NO					YES


SNAPSHOT
In the snapshot isolation the already committed records (prior to any modification) are copied to a region in tempdb called version store
This is called row versioning . The trasaction will make use of that row in the temdb rather than waiting on the blocking transaction.
Please note that SQL will aquire update lock on the record even if the transaction is SNAPSHot to make sure other transaction is not updating the data.


READ COMMITTED SNAPSHOT
This combines both the blockings. The reader uses row versioning and writer rely on locking

*/