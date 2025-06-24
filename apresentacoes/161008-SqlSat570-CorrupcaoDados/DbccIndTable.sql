		USE DBCorrupt
		IF OBJECT_ID('tempdb..#DbccInd') IS NOT NULL DROP TABLE #DbccInd;
		CREATE TABLE #DbccInd(PageFID bigint,PagePID bigint,IAMFID bigint, IAMPID bigint, ObjectID bigint,IndexID bigint,PartitionNumber bigint
								,PartitionID bigint,iam_chain_type varchar(100),PageType int,IndexLevel int,NextPageFID bigint
								,NextPagePID bigint,PrevPageFID bigint,PrevPagePID bigint)
	
		INSERT INTO #DbccInd
		EXEC('DBCC IND(''DBCorrupt'',''Lancamentos'',1)')


		select * From #DbccInd where IndexLevel = 1 