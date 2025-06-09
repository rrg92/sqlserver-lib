use master

-- rodar com o user limitado 
	select SUSER_sname()

-- caso 1: uso explicito!
	drop table if exists #TempTable1;
	select top 12800 -- >= 100MB
		c = convert(char(7000),'t')
	into 
		#TempTable1
	from
		sys.all_columns a1
		,sys.all_columns a2

	-- conferri consumo na dm_resource_governor_workload_groups


-- caso 2: uso quebrado!
	drop table if exists #TempTable1;
	select top 7000 -- >= 50MB
		c = convert(char(7000),'t')
	into 
		#TempTable1
	from
		sys.all_columns a1
		,sys.all_columns a2

	-- conferri consumo na dm_resource_governor_workload_groups

	drop table if exists #TempTable2;
	select top 7000 -- >= 50MB
		c = convert(char(7000),'t')
	into 
		#TempTable2
	from
		sys.all_columns a1
		,sys.all_columns a2

	-- conferri consumo na dm_resource_governor_workload_groups

-- clean!
	drop table if exists #TempTable1;
	drop table if exists #TempTable2;

-- caso 3: 2 sessoes dividas!
	-- abrir e nova query, DevBob
	-- rodar esse:
	drop table if exists #TempTable1;
	select top 7000 -- >= 50MB
		c = convert(char(7000),'t')
	into 
		#TempTable1
	from
		sys.all_columns a1
		,sys.all_columns a2

	-- conferri consumo na dm_resource_governor_workload_groups

--  E usi implicito tb!
	declare @top int = 10
	select top (@top)
		a = convert(char(7000),'teste')
	from
		sys.all_columns a1,sys.all_columns a2 
	where
		convert(varchar(100),a1.is_computed) = 0
	order by
		 checksum(newid()) desc

	

-- BONUS: Se vc nao sabia...

declare @Data nvarchar(max) = (

	select top 100000
		convert(char(7000),'t')
	from
		sys.all_columns a1
		,sys.all_columns a2
		,sys.all_columns a3
	for xml path

)



