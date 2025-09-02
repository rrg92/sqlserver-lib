/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 	
		(adaptado de Fausto F. Branco em http://dba-sqlserver.blogspot.com.br/2009/11/gerar-cpf-valido.htm

	# Descricao 
		Função para validar se o CNPJ (incluindo alfanumérico) é válido ou não.
		Criado como uma inline table-valued function para performance, quando usado com muitas linhas.
		Se valido, a coluna valido será 1, caso contrario nao é valido.
		Segue as regras descrita em: https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj

		Exemplo de uso:
			select * from dbo.ValidarCnpj('VCVHEYUW000118')


		Validando vários cnpjs de uma vez:

			Suponha que você tenha os cnpjs na tabela empresas, coluna cnpj.
			Para validar:

			select
				e.cnpj
				,v.valido
			from
				empresas e
				cross apply
				dbo.ValidarCnpj(e.cnpj) v

		No final o scripts deixei alguns comparativos de performance em algumas maquinas que exeucutei.
		Se você mais testes, pode atualizar o script (mesmo padrão), que eu aprovo o commit.
		
*/

USE master
GO

IF OBJECT_ID('dbo.ValidarCnpj','IF') IS NULL
	EXEC('CREATE FUNCTION dbo.ValidarCnpj() RETURNS TABLE AS RETURN (SELECT 1 as StubVersion)')
GO

ALTER FUNCTION dbo.ValidarCnpj(@cnpj varchar(14))
RETURNS TABLE 
AS RETURN (

SELECT						   
	valido =  convert(bit,case 
				when nd1 = d1 AND nd2 = d2 THEN 1
				else 0 
			end)
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
									SELECT
										 ascii(substring(@cnpj,1,1))-48		as n1
										,ascii(substring(@cnpj,2,1))-48		as n2
										,ascii(substring(@cnpj,3,1))-48		as n3
										,ascii(substring(@cnpj,4,1))-48		as n4
										,ascii(substring(@cnpj,5,1))-48		as n5
										,ascii(substring(@cnpj,6,1))-48		as n6
										,ascii(substring(@cnpj,7,1))-48		as n7
										,ascii(substring(@cnpj,8,1))-48		as n8
										,ascii(substring(@cnpj,9,1))-48		as n9
										,ascii(substring(@cnpj,10,1))-48	as n10
										,ascii(substring(@cnpj,11,1))-48	as n11
										,ascii(substring(@cnpj,12,1))-48	as n12
										,substring(@cnpj,13,1)				as nd1
										,substring(@cnpj,14,1)				as nd2
								) R								
						) C1BASE
				) C1
			) C2BASE
	) C2

)
GO





/*
Teste de performance (usando a view do script vw.GerarCNPJ-alfa), 100 mil cnpjs, ~10% invalido:

	Resultados:
		sql 2025 ctp 2.0 17.0.700.9, Intel Core i7-10750h, cpu @2.69Ghz (clock real > 4Ghz), Memoria 2667Mhz
		SQL Server Execution Times:
			CPU time = 1094 ms,  elapsed time = 1274 ms.


		sql 2019 cu16 15.0.4223.1, VM Azure Standard_E4as_v4, AMD EPYC 7452-32 Core Processor (vm com 4 cores), base speed 2.35  
		 SQL Server Execution Times:
		   CPU time = 2203 ms,  elapsed time = 3283 ms.
	
	Script de teste:
		set statistics time,io on;

		drop table if exists #cnpjs ;

		select top 100000
			case 
				when p <= 10 then stuff(cnpj,1,1,'A') 
				else cnpj 
			end as cnpj
			,p
		into 
			#cnpjs
		from
			sys.all_columns a1,sys.all_columns a2 
			cross apply
			dbo.vwGeraCNPJAlfa cnpj
			CROSS APPLY (
				SELECT p = abs(checksum(newid()))%100
			) R


		select 
			*
		from
			#cnpjs c
			cross apply
			dbo.ValidarCnpj(c.cnpj) v


sobre os testes:
	As informações são apenas da última query (o select na tab temporaira + funcao).
	Em teoria, essa é uma query que vai moer CPU e memória, I/O deve ser irrevalante aqui, mas se você testar em um ambiente cmo alta atividade, pode ser que seja afetado pelo I/O, devido apressão na memória.
	No gera, não vejo impacto sinificativo.

	CPU vai gastar, obviamente, devido ser uma fução que basicamente faz algumas operações simples.
	E memória, devido a necessidae de ler da tabela com vários dados (o que pode não caber no cache da cpu, e provavelmente vai demanda ralgumas leituras, por isso, coloquei as infos de memória, pois isso é um variável que impacta no tempo)




*/		