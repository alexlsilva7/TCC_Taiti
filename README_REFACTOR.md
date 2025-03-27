# Refactored Dependencies Extractor

## Visão Geral

Este script Ruby (`dependenciesExtractor_refactored.rb`, anteriormente `dependenciesExtractor.rb`) analisa um projeto Ruby local para encontrar as dependências de código para um conjunto específico de arquivos de entrada (arquivos "TestI"). Ele utiliza a ferramenta externa `rubrowser` para gerar os dados de dependência e processa esses dados para retornar uma lista de arquivos dependentes, relativos à raiz do projeto.

Esta é uma versão significativamente refatorada de um script anterior, focada em eficiência, simplicidade e uso direto em projetos locais sem a necessidade de interação com Git ou arquivos CSV.

## Principais Mudanças da Versão Original

A versão atual implementa várias melhorias em relação à versão original:

1.  **Execução Local Direta:** Removeu a dependência da gem `git` e a lógica de clonagem/checkout. O script agora opera diretamente em um diretório de projeto local existente, cujo caminho é fornecido como argumento.
2.  **Entrada via Argumentos:** Removeu a dependência da gem `csv` e a leitura de arquivos CSV. O caminho do projeto e a lista de arquivos TestI são passados diretamente via argumentos da linha de comando (`ARGV`).
3.  **Captura Direta do `rubrowser`:** Em vez de redirecionar a saída do `rubrowser` para um `output.html` e depois extrair o JSON via regex, o script agora executa `rubrowser --json` e captura a saída JSON diretamente na memória.
4.  **Sem Arquivos Intermediários:** Eliminou a necessidade dos arquivos `output.html` e `dependencies.json`, tornando o processo mais rápido (menos I/O de disco) e mais limpo.
5.  **Processamento Eficiente com Lookups:** O JSON capturado do `rubrowser` é processado *uma única vez* para construir estruturas de dados otimizadas (Hashes de Lookup). Isso torna a busca por definições de arquivos, definições de namespaces e relações muito mais rápida (complexidade O(1) em média), especialmente em projetos grandes ou com muitos arquivos TestI.
6.  **Saída Simplificada:** O script agora imprime apenas uma única linha no `stdout` (saída padrão) indicando o resultado: a lista de dependências encontradas (`TESTIDEP: ...`), uma mensagem de resultado vazio (`EMPTY: ...`), ou uma mensagem de erro (`ERRO: ...`). Mensagens de erro detalhadas ou avisos internos foram removidos do `stdout` (alguns erros críticos são enviados para `stderr`).
7.  **Redução de Dependências:** As únicas dependências externas agora são a própria linguagem Ruby e a gem `rubrowser`. As gems `csv`, `git`, `fileutils`, e `logger` não são mais necessárias.
8.  **Remoção de Métricas:** As funções `clean_string` e `calc_metrics` foram removidas, pois o cálculo de precisão/recall não faz parte do escopo atual do script refatorado.
9.  **Remoção de funções de teste:** As funções `new_get_all_dependencies`, `new_main`, `find_missing_name`, e `new_find_all_relations` foram removidas, pois eram funções de teste que não eram utilizadas em nenhum lugar do código.

## Pré-requisitos

1.  **Ruby:** Uma instalação funcional do Ruby.
2.  **Gem `rubrowser`:** A ferramenta `rubrowser` precisa estar instalada e acessível no `PATH` do seu sistema. Instale com:
    ```bash
    gem install rubrowser
    ```

## Uso

Execute o script a partir da linha de comando, fornecendo o caminho para o diretório raiz do projeto como primeiro argumento, seguido pelos caminhos relativos (dentro do projeto) dos arquivos TestI que você deseja analisar.

**Sintaxe:**

```bash
ruby <nome_do_script.rb> <caminho_para_o_projeto> <arquivo_testi_1> [arquivo_testi_2] [arquivo_testi_3] ...
```

Exemplo:

```bash
ruby dependenciesExtractor_refactored.rb "/caminho/para/meu/projeto_rails" \
  app/controllers/users_controller.rb \
  app/models/user.rb \
  app/helpers/users_helper.rb \
  app/views/users/show.html.erb
```

Notas:

- Coloque o <caminho_para_o_projeto> entre aspas se ele contiver espaços.

- Forneça pelo menos um <arquivo_testi>.

- Os caminhos dos arquivos TestI devem ser relativos à raiz do projeto.

## Interpretação da Saída 

- **`ERRO: <mensagem>`:**  
  Ocorre se a validação inicial de argumentos ou caminho do projeto falhar dentro da função main (antes de chamar o extractor).
  Ocorre também se ocorrer uma exceção inesperada durante a execução do begin...end principal em main (capturada pelo rescue => e).

- **`EMPTY: Nenhuma dependência encontrada ou erro durante o processo.`:**  
  Ocorre especificamente quando extractor.get_all_dependencies retorna uma string vazia (""). Isso pode acontecer se:
  - Nenhuma dependência for encontrada para os arquivos TestI fornecidos.
  - Ocorrer um erro silencioso dentro de get_all_dependencies que o faça retornar "" (embora a versão atual tente retornar strings ERROR: para falhas internas).

- **`TESTIDEP: <string_de_dependencias_ou_erro_interno>`:**  
  Ocorre quando extractor.get_all_dependencies retorna uma string não vazia. Esta string pode ser:
  - A lista de dependências encontradas, separadas por vírgula (o caso de sucesso).
  - Uma string de erro prefixada com ERROR: que foi retornada por get_all_dependencies (por exemplo, ERROR: JSON parsing failed..., ERROR: Failed to run rubrowser..., etc.).