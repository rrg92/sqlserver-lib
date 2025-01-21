# CMS Properties 

Esse foi um projeto que criei em um ambiente com várias instâncias SQL Server.  
Eu gerenciava essas instâncias usando um recurso que existe há muito tempo no SQL + Management Studio: Central Management Server (CMS).

Para acessar isso você vai, no SSMS, em View -> Registered Servers.  
Então, você vai ver uma opção Central Management Servers. Clica com o botão diretio, escolher `Register Central Management Server`.  
E aí você escolhe uma instância que irá servir como instância central.  
Então, posteriormente, você pode registrar instâncias.  

O CMS usa o msdb para guardar estes dados.  
Toda essa pasta que eu criei foi para adicionar um recurso: tags, que eu carinhosamente chamei de `CMS Properties`.  
A ideia era,na descrição das instâncias adicionar propriedades no formato `[Nome:Valor]`.  

Então, eu poderia ler isso de dentro do T-SQL, criando um jeito de categorizar e rotular minhas diferentes instâncias.  
Se não me falha a memória, eu categorizava de várias maneiras... Exemplos: [Time=Abc] (nome do time resonsável pela instância).  

Enfim, como tem tanto tempo que eu usei isso, eu não lembro exatamente para que eu usava.  
Nem sei se isso faz sentido hoje em dia.  

De qualquer modo, eu resolvi deixar os scripts e publicá-los devido a quantidade de coisas interessantes:

- Tabelas internas do msdb que podem ser úteis para alguém 
- Exemplos de queries dinâmicas 
- Exemplos de PIVOT

Pode ter algo reaproveitável aí para alguém!