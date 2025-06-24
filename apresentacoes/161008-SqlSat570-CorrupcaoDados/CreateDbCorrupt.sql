-- Criar um banco DbCorrupt e fazer um backup para ir restaurando!
USE master;
GO

IF DB_ID('DbCorrupt') IS NOT NULL
BEGIN
	EXEC('ALTER DATABASE DbCorrupt SET READ_ONLY WITH ROLLBACK IMMEDIATE')
	EXEC('DROP DATABASE DbCorrupt')
END
GO

CREATE DATABASE DbCorrupt
GO

USE DbCorrupt
GO

CREATE TABLE dbo.Lancamentos (
	DataLancamento date NOT NULL
	,NumConta int not null
	,Seq smallint  not null 
	,Tipo char(1)  not null
	,Valor money  not null
	,Moeda char(3)   not null
	,Origem char(1)  not null
	,HashLancamento uniqueidentifier not null
	,PRIMARY KEY (DataLancamento,NumConta,Seq) 
)


;with Num as (
SELECT TOP 10000
	n = ROW_NUMBER() over(order by (select null))
FROM
	sys.columns a1,sys.all_columns a2
)
insert into  dbo.Lancamentos(DataLancamento,NumConta,Seq,Tipo,Valor,moeda,Origem,HashLancamento)
select
	Dt
	,Conta.Conta
	,Seq= 1
	,Conta.Tipo
	,Valor = convert(money,(abs(checksum(newid()))%99900 + 1)/10.00)
	,Conta.Moeda
	,Conta.Origem
	,HashLancamento = newid()
from
	(
		select top 365
			Dt = convert(datetime,'20141231') + n
		from
			Num
	) Dias
	cross join
	(
		select 
			Conta = 9997 + n
			,Tipo = case
					WHEN r1 <= 92 then 'D'
					when r1 <= 99 then 'C'
					ELSE 'E'
				END
			,Moeda = case
					WHEN r2 <= 3 then 'GBP'
					when r2 <= 11 then 'EUR'
					WHEN r2 <= 21 THEN 'USD'
					ELSE 'BRL'
				END
			,Origem =  case
					WHEN r3 <= 8 then 'C'
					when r3 <= 28 then 'A'
					WHEN r3 <= 60 THEN 'I'
					ELSE 'W'
				END
		from
			num 
			cross apply (
				select 
					r1 =  abs(checksum(newid())%100 + 1)
					,r2 =  abs(checksum(newid())%100 + 1)
					,r3=  abs(checksum(newid())%100 + 1)
			) R 
	)  Conta


CREATE INDEX IX_Moeda ON Lancamentos(Moeda)
CREATE INDEX IX_Valor ON Lancamentos(Valor)
CREATE INDEX IX_Origem ON Lancamentos(Origem)


-- Guardar um backup para restores!
BACKUP DATABASE 
	DbCorrupt
TO
	DISK = 'T:\DbCorrupt.bak'
WITH
	INIT,FORMAT,COMPRESSION

	