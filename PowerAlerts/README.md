# Scripts do Power Alerts

O [Power Alerts] é uma solução de monitoramento escrito em T-SQL pela [Power Tuning].  
São mais de 80 mil linhas de código e vários alertas para monitorar o máximo de itens de uma instância T-SQL!

Este diretório contém scripts que eu fui usando (ou uso até hoje) em minhas análises em instâncias que possuem o Power Alerts.  

Os scritps aqui não são, necessariamente, padrões da Power Tuning, e são scripts que eu, enquanto DBA de um ambiente com esta solução, usei para me ajudar a encontrar algo.  

O Power Alerts, além de alertar quando há um problema, também faz uma série de coletas!  
Então, diante de um problema, saber consultar essas informações podem ajudar o DBA a identificar problemas e responder muito mais rapidamente a incidentes!  

![Power Alerts](https://poweralerts.com.br/wp-content/uploads/2023/08/Power-Alerts-Alerta-Log-Full.png)
![Power Alerts](https://poweralerts.com.br/wp-content/uploads/2023/09/Power-Reports.png)

# Um pouco mais sobre o Power Alerts 

O Power Alerts começou como scripts sql gratuitos que o [Fabrício Lima] criou para ajudar na consultoria dele, há mais de 10 anos.  
Ele viu que empresas, principalmente de pequeno porte, eram muito mais abertas a uma solução de monitoramento simples, em que era só chegar e "dar um F5" no SQL para começar a monitorar, ao invés de ter que prover infraestrutura, servidor, etc.  
Então, aqueles scrits viraram a principal ferramenta de monitoramento de muitas empresas com SQL Server pelo Brasil!

A ideia é simples: Instale no seu SQL Server e ele começa a coletar várias coisas e monitora diversos itens, enviando alertas por e-mail quando algo atinge o threshold.

A versão 3, o qual chamados de Power Alerts v3, manteve essa mesma essência, ao mesmo tempo que adicionamos muito mais elementos e rotinas, o que ajudou a fazer dessa ferramenta essencial para quem tem SQL Server!  
Hoje, o Power Alerts, além de monitorar diversos aspectos, realiza várias coletas!  
Quem é DBA há algum tempo, sabe o ouro que é você ter coletas periodicas: queries, erros, tamanho, etc.  
E a cada nova versão, podem surgir novas rotinas que ajudam a trazer mais e mais informações!  
O Power Alerts é completo assim porque ele é uma solução criada e mantida por DBA para DBAs... 
Portanto, ele vai atingir em cheio as dores de um ambiente SQL.

Uma outra grande vantagem do Power Alerts ser centralizado no T-SQL, é a portabilidade e flexibilidade.  
Todos os dados que são gerados no e-mail ficam em tabelas, que qualquer DBA pode consultar a sua livre disposição.  
É só pensar nas DMVs do SQL: O queria do DBA sem essas DMVs para que ele possa fazer comandos em cima delas e criar o monitoramento?  
O Power Alerts extende isso, trazendo os dados relevantes dessa DMV para consulta histórica!
E, como estão em tabelas, você consegue ler isso e disponibilizar em qualquer aplicação que consiga se conecta com um SQL Server!

Eu, Rodrigo, pude participar da elaboração do core dessa versão, onde trouxemos diversas melhorias de performance e funcionalidades.  
Uma delas, é a possibilidade de enviar gráficos diretamente do SQL, complementando os relatórios e alertas gerados pela ferramenta. 

Por falar em email, sim, é assim que o Power Alerts notifica usuários: e-mail.  

Mas Rodrigo, em pleno 2025, vocês ainda enviam e-mail? 
Claro! quem não recebe e-mail hoje em dia? Assim como o próprio SQL Server é uma tecnologia "antiga", mas bastante usada, o email tem todo o seu potencial.  
É simples, extremamente compatível e você pode acessar de qualquer dispositivo.

Graças a isso, qualquer empresa com apenas um SQL, já consegue ter acesso a um monitoramento mínimo e de qualidade, rica em informações textuais e visuais, apenas com um F5.  
Empresas grandes, que querem algo mais elaborado, podem ter acesso a um dashboard do PowerBI, e em algum momento, o Power Alerts também terá integrações com outras ferramentas, como Grafana.  
O fato é que o Power Alerts é para qualquer ambiente, do pequeno ao grande, ele vai ajudar o DBA a ser mais proátivo e ainda o auxilia quando preciar ser reativo! 

## Power Alerts vs Zabbix 

Falando em Grafana... o Power Alerts não é um concorrente do seu zabbix (ou similiar), ok?
Ele é um complemento! Imagine que o Power Alerts seja o plugin que seu zabbix precisa para ter o monitoramento mais completo de SQL.  

Geralmente, os templates do zabbix são bem padrões, a menos que você tenha gastado horas custmizado pra sua empresa.  
Os Admins de Zabbix (e infra em geral), tem vários problemas para se preocupar e diferentes tipos de ativos para monitorar, obviamente, não tem a expertise de um DBA para monitorar os itens certos.  
Eu digo isso com tranquilidade pois já trabalhei em uma multi nacional em que usamos Zabbix para monitorar o SQL e eu fui o responsável por customizar esse monitoramento e contornar as diversas barreiras que o Zabbix criava!  
Inclusive, através desse monitoramento, gerávamos relatórios sensacionais, como KPIs específicos pro SQL, graças a essa customizações associadas ao poder do Zabbix.  

Com o Power Alerts, você consegue ter um "agente" dentro do seu SQL coletando e gerando métricas.  
Essas coletas podem ser enviadas ao zabbix.
Além disso, a estrutura padrão de alertas do Power Alerts, foi pensada justamente para ser facilmente adaptada ao Zabbix.  
O Power Alerts é orientado a alertas... Cada alerta possui severidade (familiar?).  
Essa simples estrutura permite que você use o Power Alerts com o seu Zabbix!  

Em algum momento, a Power Tuning deve disponibilizar algo relacionado ao zabbix, e digo isso porque eu fui encarregado de fazer essa ponto.  
Estou na fase de pesquisa e testes para trazer algo bem bacana!


[Power Alerts]: https://poweralerts.com.br
[Power Tuning]: https://powertuning.com.br 
[Fabrício Lima]: https://www.fabriciolima.net/blog/


