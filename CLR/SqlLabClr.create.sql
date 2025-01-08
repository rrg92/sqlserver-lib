/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Esse script foi criado como um pequeno Lab para aprender a usar CLR.  
		O Dirceu Resende é o único doido que conheço que usa isso. 
		#Brinks #Dirceu ❤️ (Dirceu é o mito do SQL... Se você não conhece o blog dele, acesse em https://dirceuresende.com)
		
		
		Eu tenho uma preguiça de instalar o Visual Studio so pra compilar CLR rs.
		Então, eu criei um powershell que me ajuda niso.. Ele usa um compilador nativo de C# que vem no Windows...
		Recentemente, eu descobri que esse compilador é meio antiguinho... Então, pode não surportar as sintaxes mais recente do c#... 
		
		Mas pra um CLR básico, quebra um galho, ainda mais se você quer aprender...
		Então, o jeito mais fácil de usar tudo isso aqui é assim:
		
			1) Abre um powershell 
			2) Rode o arquivo compile.ps1
				CLR\compile.ps1 
			3) ele vai gerar o mesmo cnoteúdo desse arquivo, porém com a dll compilada e com o caminho completo!
			4) Se você quiser alterar o CLR, mexa no arquivo Lab.cs e execute o passo 2 novamente.
			
		OBS: Eu criei a função Sleep para explorar o internals de funcionamento do plano de execução. Um dia eu mostro isso!
		
*/
DROP FUNCTION if exists ResultAsXml,SleepRow
GO

DROP ASSEMBLY IF EXISTS SqlLabClr 
GO

CREATE ASSEMBLY SqlLabClr FROM 'SqlLabClr.dll';   
GO  

DROP FUNCTION IF EXISTS SleepRow;
GO

CREATE FUNCTION SleepRow(@ms int, @random int) RETURNS INT   
AS EXTERNAL NAME SqlLabClr.SqlLab.Sleep;   
GO  
  

DROP FUNCTION IF EXISTS SelectTable;
GO

CREATE FUNCTION SelectTable(@TableName varchar(500)) RETURNS INT   
AS EXTERNAL NAME SqlLabClr.SqlLab.SelectTable;   
GO  

CREATE FUNCTION ResultAsXml(@sql nvarchar(max)) RETURNS nvarchar(max)   
AS EXTERNAL NAME SqlLabClr.SqlLab.ResultAsXml;   
GO  


  