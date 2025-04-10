/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Traz o último CHECKDB feito em cada banco de dados.
		DBCC DBINFO é um comando não documentado e, portanto, em alguma versão futura do SQL esse script pode não funcionar!
		Até o sql 2022, tudo certo.
*/


drop table if exists #dbccinfo;

create table #dbccinfo( DbName  nvarchar(1000), ParentObject varchar(200), Object varchar(1000), Field varchar(1000), Value varchar(1000) )

-- Poderia usar sp_Msforeach db aqui também.
-- Não usei por cotna de um erro que tive em alguns testes com ela (provavelmente relacionado a algum caracter especial no nome do banco)
set nocount on;
declare @cmd nvarchar(max) = (
	select
		N'USE '+quotename(d.name)+';
		 raiserror(''Collecting Db '+d.name+''',0,1) with nowait;
		 insert into #dbccinfo(ParentObject, Object, Field, Value)
		 exec(''dbcc dbinfo with tableresults,no_infomsgs'')
		 update #dbccinfo set DBName = db_name() where DBName is null
		'
	from
		sys.databases D
	where
		d.state_desc = 'ONLINE'
	for xml path,type
).value('.','nvarchar(max)')

exec(@cmd);

select * from #DbccInfo where Field like '%dbi_dbccLastKnownGood%'