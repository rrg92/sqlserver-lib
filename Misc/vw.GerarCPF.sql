/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		(adaptado de Fausto F. Branco em http://dba-sqlserver.blogspot.com.br/2009/11/gerar-cpf-valido.html)
		
	# Descricao 
		View para gerars CPFs.
		Você pode fazer um cross apply com e gerar um cpf por linha.
		O script original usava estrutruas de loops, o que deixava difícil para adaptar em comandos SELECT ou lento (se usado como uma table function).
		Portando para uma view, você pode facilmente usar em diversos lugares e manter o máximo de performance.

		Exemplo:

			select 
				*
			from
				FakeUsers
				CROSS JOIN
				vwGeraCPF

			Esse comando acima vai gerar um cpf para cada linha da tabela FakeUsers.
*/

USE master
GO

IF OBJECT_ID('dbo.vwGeraCPF','V') IS NULL
	EXEC('CREATE VIEW dbo.vwGeraCPF as select 1 StubVersion')
GO

ALTER VIEW dbo.vwGeraCPF
AS
			


		SELECT
			cpf =	convert(varchar(1),n1)+ 
					convert(varchar(1),n2)+
					convert(varchar(1),n3)+
					convert(varchar(1),n4)+
					convert(varchar(1),n5)+
					convert(varchar(1),n6)+
					convert(varchar(1),n7)+
					convert(varchar(1),n8)+
					convert(varchar(1),n9)+
					convert(varchar(1),d1)+
					convert(varchar(1),d2)
		FROM
			(
				SELECT 
					  C2BASE.*
					 ,d2 = CASE 
							WHEN d2calc%11 < 2 THEN 0
							ELSE 11-d2calc%11
						END
					
				FROM (
					SELECT
						C1.*
						,d2calc =  d1*2+n9*3+n8*4+n7*5+n6*6+n5*7+n4*8+n3*9+n2*10+n1*11
					FROM
						(

							SELECT
								CASE
									WHEN d1calc%11 < 2 THEN 0
									ELSE 11-d1calc%11 
								END as d1
								,C1BASE.*
							FROM
								(
									SELECT 
										*
										,d1calc = (n9*2+n8*3+n7*4+n6*5+n5*6+n4*7+n3*8+n2*9+n1*10)%11
									FROM 
										(
											SELECT
												 convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n1
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n2
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n3
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n4
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n5
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n6
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n7
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n8
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%9 as n9
										) R
								) C1BASE
						) C1
					) C2BASE
			) C2

			