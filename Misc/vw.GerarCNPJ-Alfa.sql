/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		(adaptado de Fausto F. Branco em http://dba-sqlserver.blogspot.com.br/2009/11/gerar-cpf-valido.html)	
		
	# Descricao 
		View para gerars CNPJ alfanumérico
		Você pode fazer um cross apply com e gerar um cnpj por linha.
		Usado estes documentados como fonte do cálculo e validação: https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj
*/

USE master
GO

IF OBJECT_ID('dbo.vwGeraCNPJAlfa','V') IS NULL
	EXEC('CREATE VIEW dbo.vwGeraCNPJAlfa as select 1 StubVersion')
GO

ALTER VIEW dbo.vwGeraCNPJAlfa
AS
			

		

		SELECT						   
			cnpj =	char(48+n1)+ 
					char(48+n2)+
					char(48+n3)+
					char(48+n4)+
					char(48+n5)+
					char(48+n6)+
					char(48+n7)+
					char(48+n8)+
					char(48+n9)+
					char(48+n10)+
					char(48+n11)+
					char(48+n12)+
					convert(char(1),d1)+
					convert(char(1),d2)
					,*
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
										,d1calc =  n1*5 + n2*4 + n3*3 + n4*2 + n5*9 + n6*8 + n7*7 + n8*6 + n9*5 + n10*4 + n11*3 + + n12*2
									FROM 
										(
											SELECT -- Como não podemos usar os numeros 10 a 16, então, fazemos um if.
												 n1 = case when n1 between 10 and 16 then n1+7 else n1 end
												,n2 = case when n2 between 10 and 16 then n2+7 else n2 end
												,n3 = case when n3 between 10 and 16 then n3+7 else n3 end
												,n4 = case when n4 between 10 and 16 then n4+7 else n4 end
												,n5 = case when n5 between 10 and 16 then n5+7 else n5 end
												,n6 = case when n6 between 10 and 16 then n6+7 else n6 end
												,n7 = case when n7 between 10 and 16 then n7+7 else n7 end
												,n8 = case when n8 between 10 and 16 then n8+7 else n8 end
												,n9 = case when n9 between 10 and 16 then n9+7 else n9 end
												,n10 
												,n11
												,n12 
											FROM (
												SELECT
													 convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n1
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n2
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n3
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n4
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n5
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n6
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n7
													,convert(int,1000*RAND(CHECKSUM(NEWID())))%43 as n8
													,convert(int,0) as n9
													,convert(int,0) as n10
													,convert(int,0) as n11
													,convert(int,1) as n12
											) S
										) R
								) C1BASE
						) C1
					) C2BASE
			) C2

			