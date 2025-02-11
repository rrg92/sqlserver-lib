/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes
		O objetivo desse código é mostrar como o NULL pode ser prejudicial ao ser usado em filtros, especialmente NOT IN!		
   
*/


drop table if exists #vendas;
create table #vendas (
	DataVenda datetime 
	,TotalVenda decimal(10,5)
	,ip varchar(100)
)

drop table if exists #regras; 
create table #regras (
	 Hora int 
	,ip varchar(100)
	,email varchar(100)
	,dns varchar(100)
	,username varchar(100)
)

insert into #vendas 
values 
	('20240101 15:41',1500,'1.2.3.4')
	,('20240101 16:41',1500,'1.2.3.4')
	,('20240102 16:00',3000,'4.5.6.7')
	,('20240102 15:39',150,'1.1.1.1')
	,('20240102 15:39',3000,'2.2.2.2')

insert into #regras(Hora,ip,email,dns,username)
values 
	(15,'1.1.1.1',null,null,null)
	,(16,null,null,'*.test',null)

select
	 Dia			= convert(date,DataVenda)
	,TotalVenda		= sum(TotalVenda)
from
	#vendas v
where 
	v.ip not in (
		select b.ip from #regras b
		where b.Hora = datepart(hh,DataVenda)
	)
group by
	convert(date,DataVenda)

-- fix 1: is not null
select
	 Dia			= convert(date,DataVenda)
	,TotalVenda		= sum(TotalVenda)
from
	#vendas v
where 
	v.ip not in (
		select b.ip from #regras b
		where b.Hora = datepart(hh,DataVenda)
		and b.ip is not null
	)
group by
	convert(date,DataVenda)

-- fix 2: isnull
select
	 Dia			= convert(date,DataVenda)
	,TotalVenda		= sum(TotalVenda)
from
	#vendas v
where 
	v.ip not in (
		select isnull(b.ip,'') from #regras b
		where b.Hora = datepart(hh,DataVenda)
	)
group by
	convert(date,DataVenda)

-- fix 3: not exists
select
	 Dia			= convert(date,DataVenda)
	,TotalVenda		= sum(TotalVenda)
from
	#vendas v
where 
	not exists (
		select * from #regras b
		where b.Hora = datepart(hh,DataVenda)
		and v.ip = b.ip
	)
group by
	convert(date,DataVenda)

-- fix 4: ANSI_NULLS (dificlmente voce vai querer mexer nisso, até pq é deprecated! Mas tá ai so pra saber!)
SET ANSI_NULLS OFF;
GO

select
	 Dia			= convert(date,DataVenda)
	,TotalVenda		= sum(TotalVenda)
from
	#vendas v
where 
	v.ip not in (
		select b.ip from #regras b
		where b.Hora = datepart(hh,DataVenda)
	)
group by
	convert(date,DataVenda)
GO

SET ANSI_NULLS ON;
go




