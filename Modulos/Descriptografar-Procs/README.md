# Como descriptografar procedures 

Os scripts desse diretório contém procedures que ajudam a descriptografar as procedures criptografadas com o WITH ENCRYPTION.  
Para conseguir descriptografar, você deve ter acesso de sysadmin na instância e conseguir conectar como DAC.  
Ou seja, esse procedimento é so para quem tem nível muito alto de acesso ao SQL.

Os scripts aqui foram adaptados com base  no blog: https://sqlperformance.com/2016/05/sql-performance/the-internals-of-with-encryption, que aliás, é um excelente post explicando como o WITH ENCRYPTION funciona.

> [!WARNING]
> Esse procedimento não é oficial Microsoft e você deve usar por sua própria e risco 
> Apesar disso, eu nunca vi nenhum efeito colateral, visto que você só faz mais consulta e cria funçoes t-sql escalares simples.
> Porém, lembre-se que o DAC é uma conexão especial, para resolver emergências, e não deve ser mantido aberta sem necessidade.
> Outro ponto importante é que os scripts vão consultar DMVs e metadados com informações sensíveis da instância, como keys, então, não compartilhe isso.
> Por isso, tenha em mente que é de seu inteira responsabilidade seguir com o uso e os procedimentos descritos aqui.

Procedimentos:
	
- Cria [esta função](fn.Rc4.sql).  
- Conecte-se como dac e [rode este script](DecryptSelectProcs.sql) no banco desejado para trazer as procs descriptogradas.
	- Se der erro de conversão de XML, siga as orientações no comentário no início do SELECT