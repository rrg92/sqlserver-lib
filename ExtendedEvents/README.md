# Extended Events 

Esse é o diretório onde guardo as queries relacionadas ao XE  (Extended Events) do SQL Server.  
Eu jogo scritps aqui desde que isso surgiu no 2008, que foi onde comecei com SQL Server. 

Na raiz, tem alguns scripts gerais para lidar com o XE, ou obter informações.  

E, você vai ver vários subdiretórios, onde meu objetivo era deixar alguns eventos prontos para dar um F5, junto com as respectivas queries para coletar e analisar.  

Em tese, cada diretório seria uma "categoria" ou representaria um problema ou conjunto de eventos que precisaria capturar.  
E dentro do diretório, teria um arquivo event_create.sql com a definição do evento, e outro query_*, com a definição da query para consultar o target, onde * seria o respectivo target.  

Eu provavelmente não conseguir manter esse padrão bonitinho assim, mas deve notar que gira em torno disso.
