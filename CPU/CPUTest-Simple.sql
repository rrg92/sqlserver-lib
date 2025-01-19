/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Este é um simple tests pra moer 1 CPU usa!
		A ideia é muito simples: Faça um LOOP decrementando um variável e calcule o tempo que isso levou!
		Você pode rodar o mesmo teste em outra instancia, copiando e colando e matendo os mesmos resultados!
		E,c om isso, você pode comparar e perceber diferenças!
		Se o mesmo teste, com o mesmo parâmetros, apresentar diferenças no tempo, você sabe que tem algo impactando!
		Esse alg pode ser: carga do ambiente, config de hardware, config o seu So, etc.
		A causa exata é outro trabalho.
		O objetivo desse script é testar e ver se há diferença significativas!

		Eu uso sql dinamico com set nocount, devido a um comportamento do sql.
		Sem isso, a cada loop, ele enviaria uma mensagem ao client, fazendo com o que teste não consumissse a cpu devido a espera!
*/
exec sp_Executesql  N'
set nocount on;
declare @start_cpu datetime = getdate();
DECLARE @i bigint = 10000000
while @i > 0 set @i -= 1;
select UsedCPU = datediff(ms,@start_cpu, getdate())
'