# ServiceHub API

**Aluno:** Gabriel Eduardo de Lima  
**Matrícula:** 2410433

API REST acadêmica para contratação de serviços, com usuários CLIENT e PROVIDER, ofertas, solicitações e avaliações. Inclui CRUD, PATCH, filtros, paginação, validações, documentação OpenAPI e testes automatizados.

## Execução rápida do pacote

Requer Java 21 ou superior. No Windows, abra **iniciar.cmd** na raiz do projeto. Ele executa o JAR de `dist/` sem baixar dependências Maven. Mantenha o terminal aberto e aguarde `Tomcat started on port 8080`. Para encerrar, pressione Ctrl+C. Se a porta estiver ocupada, encerre a execução anterior ou defina a variável PORT antes de iniciar.

Para executar o código durante o desenvolvimento, instale **JDK 21** e **Maven 3.6.3+**:

```powershell
mvn spring-boot:run
```

Nesta máquina, `.executar.ps1` também encontra o JDK 21 e o Maven fornecidos pelo IntelliJ quando JAVA_HOME e Maven não estiverem configurados. Em outros computadores, configure JAVA_HOME e PATH.

## URLs

- Swagger UI: http://localhost:8080/swagger-ui.html
- OpenAPI JSON: http://localhost:8080/v3/api-docs
- Diagnóstico: http://localhost:8080/api/hello
- O caminho antigo `/api-docs` redireciona para `/v3/api-docs`.

O Swagger contém o nome do aluno, matrícula, versão v1.0.0, contato e licença de uso acadêmico. Não foi inventado um endereço de e-mail para o contato.

## Tecnologias e arquitetura

Java 21, Spring Boot 3.5.5, Maven, Spring Web MVC, Spring Data JPA, Hibernate, Bean Validation, Lombok, Flyway, H2, PostgreSQL, Springdoc OpenAPI 2.8.9, JUnit e Spring Boot Test/MockMvc. Senhas recebem hash BCrypt por spring-security-crypto; isso não implementa autenticação.

O Controller recebe HTTP e delega ao Service. O Service valida regras e coordena transações. Os repositories acessam o banco. DTOs de entrada e saída impedem exposição das entidades JPA e de senhas ou hashes. As dependências usam injeção por construtor.

```text
src/main/java/com/servicehub/
  controller/   Endpoints e documentação
  service/      Regras, transações, paginação e PATCH
  repository/   Interfaces Spring Data JPA
  model/        Entidades e enums
  dto/          Requests, responses e erros
  exception/    Exceções e tratamento global
  config/       OpenAPI
src/main/resources/db/migration/  V1 a V5
src/test/java/com/servicehub/     Integração e migração
docs/                             Diagrama, OpenAPI e evidências
dist/                             JAR compilado
```

## Banco e variáveis de ambiente

O perfil padrão `local` usa H2 em arquivo em `data/`, persistindo dados entre reinicializações. Testes usam H2 em memória. Flyway aplica as migrations e Hibernate utiliza `ddl-auto=validate`.

| Variável | Padrão | Finalidade |
|---|---|---|
| PORT | 8080 | Porta HTTP |
| SPRING_PROFILES_ACTIVE | local | Use postgres para PostgreSQL |
| DB_URL | jdbc:postgresql://localhost:5432/servicehub | Conexão PostgreSQL |
| DB_USER | servicehub | Usuário PostgreSQL |
| DB_PASSWORD | servicehub_local | Senha apenas de desenvolvimento |
| DB_NAME | servicehub | Nome do banco no Compose |
| DB_PORT | 5432 | Porta exposta pelo Compose |

Se alterar DB_PORT/DB_NAME no Compose, ajuste DB_URL na aplicação. O arquivo `.env` alimenta o Compose; a aplicação recebe variáveis do terminal/processo.

Com Docker Desktop em execução:

```powershell
docker compose -f docker-compose.yml up -d
$env:SPRING_PROFILES_ACTIVE = 'postgres'
$env:DB_URL = 'jdbc:postgresql://localhost:5432/servicehub'
$env:DB_USER = 'servicehub'
$env:DB_PASSWORD = 'servicehub_local'
mvn spring-boot:run
```

Para voltar ao H2 no mesmo terminal:

```powershell
Remove-Item Env:SPRING_PROFILES_ACTIVE -ErrorAction SilentlyContinue
mvn spring-boot:run
```

V1 a V4 criam as tabelas e restrições do domínio. V5 acrescenta papéis e índices sem apagar dados: usuários que já possuem ofertas recebem PROVIDER, os demais CLIENT. Históricos existentes são preservados. Não edite migrations já aplicadas.

## Endpoints e paginação

Cada coleção possui POST e GET. Cada item `/{id}` possui GET, PUT, PATCH e DELETE:

| Recurso | URI |
|---|---|
| Usuários | /api/v1/users |
| Serviços | /api/v1/services |
| Solicitações | /api/v1/service-requests |
| Avaliações | /api/v1/reviews |

Consultas relacionadas: GET `/api/v1/users/{id}/services`, `/api/v1/users/{id}/service-requests` e `/api/v1/services/{id}/reviews`.

GET de coleção retorna `{content, page, size, totalElements, totalPages}`. `page` começa em zero, `size` tem padrão 20 e máximo 100. Exemplo: `/api/v1/services?page=0&size=5&sort=price,asc`. O resolver do Spring ajusta valores negativos de página e tamanhos fora do limite. Campos de ordenação não permitidos retornam 400.

Filtros: usuários por `email`; serviços por `category`, `minPrice`, `maxPrice`, `active`, `providerId`; pedidos por `status`. Filtros de serviços podem ser combinados. O sub-recurso de serviços do usuário lista somente ofertas ativas. O sub-recurso de pedidos lista os pedidos em que o usuário é cliente.

POST retorna 201 e Location, consultas e atualizações retornam 200, exclusão retorna 204 sem corpo. Erros: 400 dados inválidos, 404 inexistente, 409 conflito, 415 formato não suportado. Também são tratados 405, 406 e falhas inesperadas 500.

## PUT e PATCH

PUT exige todos os campos obrigatórios de entrada e substitui os editáveis. Opcionais omitidos são limpos. PATCH aceita um objeto JSON apenas com os campos a modificar. Campos omitidos permanecem intactos. `null` limpa somente campos opcionais; campos obrigatórios nulos são inválidos. Campos desconhecidos ou gerados pelo servidor são rejeitados. No PATCH de usuário, senha omitida preserva o hash atual. No PUT, senha é obrigatória.

## Regras de negócio

- E-mail normalizado e único; senha de 8 a 60 caracteres e no máximo 72 bytes UTF-8, sem retorno de senha/hash.
- Somente PROVIDER ativo pode possuir uma oferta. Preço maior que zero, com duas casas decimais.
- Novo pedido exige cliente CLIENT ativo, serviço e prestador ativos. O cliente e o prestador devem ser diferentes.
- Novo pedido começa em PENDING. Avanços: PENDING para ACCEPTED, ACCEPTED para IN_PROGRESS, IN_PROGRESS para COMPLETED. CANCELLED é permitido antes da conclusão. Repetir o estado atual é permitido.
- Serviço e cliente do pedido são imutáveis. O preço é registrado na criação e não acompanha mudanças posteriores na oferta.
- Uma avaliação por pedido COMPLETED, nota de 1 a 5 e reviewerId igual ao cliente do pedido. Pedido e avaliador não mudam no PUT/PATCH.
- Relacionamentos impedem exclusões inconsistentes. Não há exclusões automáticas em cascata.
- O papel de usuário com ofertas ou pedidos não pode mudar. CLIENT/PROVIDER são regras de domínio, não autorização de acesso.

## Exemplos cURL

No PowerShell use `curl.exe` no lugar de `curl` caso exista um alias para Invoke-WebRequest. Os exemplos de POST leem arquivos para evitar problemas de escape de JSON no Windows.

```text
curl http://localhost:8080/api/hello
curl -i -X POST http://localhost:8080/api/v1/users -H "Content-Type: application/json" --data-binary @docs/payloads/provider.json
curl -i -X POST http://localhost:8080/api/v1/users -H "Content-Type: application/json" --data-binary @docs/payloads/client.json
curl -i -X POST http://localhost:8080/api/v1/services -H "Content-Type: application/json" --data-binary @docs/payloads/service.json
curl "http://localhost:8080/api/v1/services?category=TECNOLOGIA&minPrice=100&maxPrice=200&page=0&size=5"
curl -i -X PATCH http://localhost:8080/api/v1/services/1 -H "Content-Type: application/json" --data-binary @docs/payloads/service-patch.json
curl -i -X DELETE http://localhost:8080/api/v1/services/1
curl -i http://localhost:8080/api/v1/services/1
```

Substitua IDs pelos retornados na sua execução. Os arquivos de exemplo consideram prestador 1, cliente 2, serviço 1 e pedido 1. O roteiro HTTP em `requests.http` detalha o fluxo completo. DELETE de serviço com pedidos retorna 409: remova primeiro as avaliações e os pedidos criados na demonstração.

## Testes e build

```powershell
mvn test
mvn clean verify
```

Alternativas nesta máquina: `.executar.ps1 -Testar` e `.executar.ps1 -Verificar`. Os testes usam H2 isolado e verificam CRUD, papéis, PATCH, paginação, filtros, transições, avaliações, documentação e migração de um banco V4 para V5 sem perda de dados. O pacote executável fica em `target/servicehub-api-1.0.0.jar`. Após alterar código, copie o JAR recompilado para `dist/` para atualizar `iniciar.cmd`.

## Documentação e apresentação

Abra `docs/diagrama_endpoints_Gabriel_Eduardo_de_Lima.md` ou o PDF correspondente. O Markdown contém Mermaid e detalha as 30 operações. O JSON OpenAPI é extenso porque descreve o contrato completo; schemas são reutilizados por `$ref`.

`docs/roteiro-apresentacao.md` organiza 8 a 10 minutos. `docs/evidencias` contém registros reais das respostas HTTP e instruções para capturas de tela. Os payloads usam pessoas fictícias, sem dados pessoais reais. A identificação acadêmica aparece somente na documentação.

## Limites atuais

O esquema bearerAuth está documentado, mas não há emissão/validação JWT nem autorização. As operações são públicas e o servidor escuta apenas localhost por padrão. O contato identifica o aluno, sem e-mail não fornecido. O PostgreSQL está configurado; consulte `docs/verificacao.md` para distinguir os testes realizados no H2 das validações que exigem Docker Desktop funcionando.


## JAR executável gerado
`java -jar dist/servicehub-api-gabriel-2410433.jar --spring.profiles.active=local`
