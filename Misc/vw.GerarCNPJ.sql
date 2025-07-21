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

--IF OBJECT_ID('dbo.vwGeraCPF','V') IS NULL
--	EXEC('CREATE VIEW dbo.vwGeraCPF as select 1 StubVersion')
--GO

--ALTER VIEW dbo.vwGeraCPF
--AS
			


		SELECT
			cnpj =	convert(varchar(1),n1)+ 
					convert(varchar(1),n2)+
					convert(varchar(1),n3)+
					convert(varchar(1),n4)+
					convert(varchar(1),n5)+
					convert(varchar(1),n6)+
					convert(varchar(1),n7)+
					convert(varchar(1),n8)+
					convert(varchar(1),n9)+
					convert(varchar(1),n10)+
					convert(varchar(1),n11)+
					convert(varchar(1),n12)+
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
						,d2calc =  n1*6 + n2*5 + n3*4 + n4*3 + n5*2 + n6*9 + n7*8 + n8*7 + n9*6 + n10*5 + n11*4 + + n12*3 + d1*2
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
										,d1calc = (n12*2+n11*3+n10*4+n9*5+n8*6+n7*7+n6*8+n5*9+n4*2+n3*3+n2*4+n1*5)%11
									FROM 
										(
											SELECT
												 convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n1
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n2
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n3
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n4
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n5
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n6
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n7
												,convert(int,1000*RAND(CHECKSUM(NEWID())))%10 as n8
												,convert(int,0) as n9
												,convert(int,0) as n10
												,convert(int,0) as n11
												,convert(int,1) as n12
										) R
								) C1BASE
						) C1
					) C2BASE
			) C2

			