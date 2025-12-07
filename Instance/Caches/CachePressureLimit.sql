/*info 
	
	# autor 
		Rodrigo rieiro Gomes 

	# descricao 
		Cálculos para determinar o PLAN CACHE Pressure Limit
		Script que criei provavelmente enquanto estava estudando isso e fui comentnaod para deixar um scrip e um texto como eu estava entendendo tudo.
		Isso foi epoca do 2005/2008 ainda, muita coisa pode ter mudado 20 anos depois!


		Table 5-3 em http://technet.microsoft.com/en-us/library/cc293624.aspx
		
		TGV = target visible memory ( não engloba AWE. )

		SQL 2005 SP1	- 75% de TGV[0-8GB] + 50% de TGV[8-64GB] + 25% de TGV[>64GB]
		SQL 2005 SP2	- 75% de TGV[0-4GB] + 10% de TGV[4-64GB] +  5% de TGV[>64GB]
		SQL 2000		- Passou de 4GB considera memory pressure!

		Local Memory pressure ( independente a cada uma das stores, neste caso as de plan cache )
			Condições ( se ocorrer qualquer uma das seguintes ) 
				- 75% do Pressure Limit (Single-Page)
				- 50% do Pressure Limit (Multi-Page)
				- Número de plans = 4*HashTableSize
			Obs:
				- Se o limite for atingindo quando o add o plan para o cache, a mesma thread que add é usada para remover!!!

		Global Memory Pressure ( Todas os caches stores terão entradas removidas )
			Internal
				Condições:
					- Virtual address space is low
					- Memory broker diz que todas stores devem usar 80% do Pressure Limit
			External
				Condições:
					- Sistema operacional pede memória!

*/

--> Determinando qual o Pressure Limit( considerando SQL 2005 SP2 ou > )
DECLARE
	@MemVisivelGB INT
SET @MemVisivelGB = 2
SELECT 
	 (@MemVisivelGB*0.75)		as PressureLimit
	,(@MemVisivelGB*0.75)*0.75	as LocalPressureSPLimit
	,(@MemVisivelGB*0.75)*0.5	as LocalPressureMPLimit