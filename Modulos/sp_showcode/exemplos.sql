/*#info 
	
	# autor 
		Rodrigo Ribeiro Gomes
	# descriçao
		Algumas demonstrações de uso da sp_showcode
		Usado o banco Traces, que contém o Power Alerts (https://poweralerts.com.br/)
*/


-- mostrar o codigo de procedure de usuario
sp_showcode stpPowerAlert_Identity_Values
sp_helptext  stpPowerAlert_Identity_Values -- diferenca da sp_helptext

-- mostra o codigo de uma proc de sistema
sp_showcode 'sp_help'

-- criptografada?
-- Use Traces
sp_showcode spencrypted

-- ver o codigo como xml (igual a sp_whoisactive)
sp_showcode sp_help,'xml'

-- Listar top 50 objetos (que tem codigo) no banco atual
sp_showcode '%' 
sp_showcode '%',@top = 0 -- todos


-- todos os objetos que contém as palavras alert e log
sp_showcode '%filegroup%'
sp_showcode '%filegroup%',@all = 1 -- manda exibir todos!
sp_showcode '%filegroup%','xml',@all = 1 -- manda exibir todos como xml

-- um objeto que não lembra o nome exato!
sp_showcode '%alert%full%' -- se tiver 1, ja exibe!


-- multiplos schemas banco atual
sp_showcode '%.%test%'

-- em toda a instancia
sp_showcode '%..%test%'
sp_showcode '%..%test%','xml',@all = 1 -- tudo como xml

-- em um banco diferente do atual!
sp_showcode 'master..ddl%'
master..sp_showcode 'ddl%' -- tb vale
master..sp_helptext ddl_trig_database -- curiosidade: sp_helptext nao lista triggers ddl!

-- colunas computadas
sp_showcode '%/fl%'





