/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Adiciona um logical device.
		Geralmente fazemos backup direto para um arquivo.
		Mas o comando suporta BACKUP para um "device lógico", que é um arquivo fixo, e você referencia por um nome interno, ao invés do caminho.

		Eu confesso que raramente usei isso, mas devo ter guardado isso aqui para ter um exemplo dos parâmetros ou para resolver algum problema.
		O comentário com '--> Obsoleto', se não me engano, são parâmetros obsoletos.
	
*/

sp_addumpdevice 
 @devtype		= 'disk'
,@logicalname	= 'DIR_PADRAO_BANCOS' 
,@physicalname	= 'C:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\DATA\'
--> Obsoleto
--,@cntrltype		= 
--,@devstatus		= 


