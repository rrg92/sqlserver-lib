/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Descrição 
		Um simples script (que pode ser transfromado em proc, funcao, etc. para fazer o parse de string no formato:
			OPCAO1,OPCAO2,OPCAO3,OPCAO\,ESCAPE,OPCAO-BARRA-FIM\\,BARRA\\ESCAPE

		O script quebra uma string nas virgulas. Caso queria incluir uma virgula, escpae com \,. 
		Se vc quiser incluir um "\," (barra segudo de virgula) escape a barra e a virgula \\ + \,
		
		Assim, você tem um pequeno interpreador de expressoes que pode ser usado em procedures.
		A primeira ideia que vi isso nas procedures do Ola Hallegren, onde vc pode especificar expressoes como %,-sys,-%teste% para filtrar banco.
		Nunca vi a implementação dele, e resolvi deixar aqui uma versão minha que você pode usar e adaptar onde precisar (procs, funcoes, etc.)

		O script inclui uma pequena validação do resultado esperado Não esquea de remover a validação ao usar.
*/


declare
	@Expr nvarchar(max) = N'%,Isso é um escape\,e vai continuar aqui!,Barra no fim:\\,Barra no \ meio!,Barra com virgual no fim:\\\,,Unicode❤️Chars,EncerradoComBarra\'



declare
	 @i int = 0
	,@len int = len(@expr)
	,@CurrentChar nvarchar(1), @NextChar nvarchar(1)
	,@buff nvarchar(max) = ''

declare @Result table(id int identity not null,expr nvarchar(max))


while @i <=	@len 
begin
	set @i += 1;
	set @CurrentChar = substring(@expr+',',@i,1)
	set @NextChar = substring(@expr,@i+1,1)

	if @CurrentChar = '\' and @NextChar in ('\',',')
		select @buff += @NextChar, @i += 1;
	else if @CurrentChar = ',' 
	begin
	   insert into @Result(expr) values(@buff)
	   set @buff = '';
	end else
		set @buff += @CurrentChar
	
end


declare
	@Esperado table (id int identity not null,expr nvarchar(max))

insert into @Esperado values 
	(N'%'),(N'Isso é um escape,e vai continuar aqui!')
	,(N'Barra no fim:\'),(N'Barra no \ meio!')
	,(N'Barra com virgual no fim:\,')
	,(N'Unicode❤️Chars')
	,(N'EncerradoComBarra\')
	

select
	*
	,OK = case 
			when e.expr = r.expr collate Latin1_General_BIN then 1
			else 0
		end
from
	@Esperado e
	full join
	@Result r
		on e.id = r.id
