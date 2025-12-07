/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Algum script que usei por curiosidade e estudi apenas para mapear as informacoes do Virtual Address Space do SQL

*/




/*
	Links úteis:
		BOL da dmv - http://msdn.microsoft.com/en-US/library/ms186294(v=SQL.90).aspx
		BOL da VirtualQuery - http://msdn.microsoft.com/en-us/library/aa366902(v=vs.85).aspx
		BOL da MEMORY_BASIC_INFORMATION - http://msdn.microsoft.com/en-us/library/aa366775(v=vs.85).aspx
*/

;WITH ssvas AS
(
SELECT	
	 vad.region_allocation_base_address	AS InicioRegiaoAlocada	--> Ponteiro retornado por VirtualAlloc
	,CASE vad.region_allocation_protection
		WHEN 0x00000010	THEN 'PAGE_EXECUTE'
		WHEN 0x00000020	THEN 'PAGE_EXECUTE_READ'
		WHEN 0x00000040	THEN 'PAGE_EXECUTE_READWRITE'
		WHEN 0x00000080	THEN 'PAGE_EXECUTE_WRITECOPY'
		WHEN 0x00000001	THEN 'PAGE_EXECUTE_NOACCES'
		WHEN 0x00000002	THEN 'PAGE_READONLY'
		WHEN 0x00000004	THEN 'PAGE_READWRITE'
		WHEN 0X00000008	THEN 'PAGE_WRITECOPY'
		WHEN 0x00000100	THEN 'PAGE_GUARD'
		WHEN 0X00000200	THEN 'PAGE_NOCACHE'
		WHEN 0x00000400	THEN 'PAGE_WRITECOMBINE'
		ELSE 'SEM_ACESSO'
	  END								AS RegiaoAlocadaProtecao	--> Tipo de proteção aplicada quando VirtualAlloc foi chamado.
	,vad.region_base_address			AS InicioFaixaPaginas		--> Inicio da faixa de páginas dentro da regiao acima, com os mesmos atributos.
	,vad.region_size_in_bytes			AS FaixaPaginasBytes		--> Quantidade de bytes na faixa de páginas.
	,CASE vad.region_state
		WHEN 0x00001000	THEN 'MEM_COMMIT'
		WHEN 0x00010000	THEN 'MEM_FREE'	
		WHEN 0x00002000	THEN 'MEM_RESERVE'
	 END								AS FaixaPaginasEstado		--> COMITADO | RESERVADO | FREE : estado das páginas na região.
	,CASE vad.region_current_protection
		WHEN 0x00000010	THEN 'PAGE_EXECUTE'
		WHEN 0x00000020	THEN 'PAGE_EXECUTE_READ'
		WHEN 0x00000040	THEN 'PAGE_EXECUTE_READWRITE'
		WHEN 0x00000080	THEN 'PAGE_EXECUTE_WRITECOPY'
		WHEN 0x00000001	THEN 'PAGE_EXECUTE_NOACCES'
		WHEN 0x00000002	THEN 'PAGE_READONLY'
		WHEN 0x00000004	THEN 'PAGE_READWRITE'
		WHEN 0X00000008	THEN 'PAGE_WRITECOPY'
		WHEN 0x00000100	THEN 'PAGE_GUARD'
		WHEN 0X00000200	THEN 'PAGE_NOCACHE'
		WHEN 0x00000400	THEN 'PAGE_WRITECOMBINE'
		ELSE 'SEM_ACESSO'
	  END								AS FaixaPaginasProtecao		--> Tipo de proteção atual das páginas
	,CASE vad.region_type
		WHEN 0x01000000	THEN 'MEM_IMAGE'
		WHEN 0x00040000	THEN 'MEM_MAPPED'
		WHEN 0x00020000	THEN 'MEM_PRIVATE'
	 END								AS FaixaPaginasTipo
FROM
	sys.dm_os_virtual_address_dump vad
)
SELECT
	 sv.FaixaPaginasEstado
	,sv.FaixaPaginasTipo
	,COUNT(DISTINCT sv.InicioRegiaoAlocada)
	,COUNT(sv.InicioFaixaPaginas)			
	,SUM(sv.FaixaPaginasBytes)
FROM
	ssvas sv
--WHERE
--	sv.InicioFaixaPaginas in (0x00000000)
GROUP BY
	 sv.FaixaPaginasEstado
	,sv.FaixaPaginasTipo
ORDER BY
	 sv.FaixaPaginasEstado
	,sv.FaixaPaginasTipo