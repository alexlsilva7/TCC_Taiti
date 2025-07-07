- removido a função **find_missing_name** do código pois quebra a execução do código (o proprio autor do código comentou que a função estava em fase de testes e não era para ser utilizada)

- removido a função **new_get_all_dependencies, new_main, e new_find_all_relations** do código pois eram funções de teste que não eram utilizadas em nenhum lugar do código.

- removido a dependencia **parser** do codigo pois só era utilizada na função **find_missing_name** que não era utilizada em nenhum lugar do código, porém a gem é uma dependencia do rubrowser e é baixada automaticamente quando o rubrowser é baixado.
  - removido a função **find_missing_name** do código
  - removido o require da gem **parser** do código

- **Refatoração do Script de Extração de Dependências:** O script evoluiu de uma ferramenta de linha de comando que processava CSVs para um script de relatório mais robusto e focado em depuração.
  - **Remoção do Cálculo de Métricas:** A funcionalidade de calcular precisão, recall e F2-score foi removida para focar puramente na extração de dependências.
  - **Simplificação da Entrada/Saída:** A leitura de arquivos CSV foi substituída por dados de teste embutidos no código, e a saída foi alterada de um arquivo CSV para um relatório formatado no console.
  - **Melhora na Qualidade do Código:**
    - Estruturas de dados de entrada foram alteradas de strings para arrays, eliminando a necessidade de funções de limpeza de strings.
    - O tratamento de erros para operações Git foi aprimorado, tornando o script mais resiliente.
    - As dependências `logger` e `csv` foram removidas nas versões finais.

## Evolução Detalhada dos Scripts

### dependenciesExtractor.rb → dependenciesExtractor2.rb
- **Removida funcionalidade de cálculo de métricas:** Eliminação da função `calc_metrics` e das colunas de precisão, recall e F2-score no CSV de saída
- **Simplificação do CSV de saída:** O arquivo de saída passou a conter apenas a coluna `TestIDep` ao invés de múltiplas métricas
- **Foco na extração:** O script passou de uma ferramenta de avaliação para uma ferramenta focada apenas na extração de dependências

### dependenciesExtractor2.rb → dependenciesExtractor3.rb
- **Transformação para script de teste:** Substituição da leitura dinâmica de CSVs por dados hardcoded para teste de um único repositório
- **Dados de teste embutidos:** Criação das estruturas `task_data` e `taiti_data` com informações específicas do repositório `bsmi`
- **Mudança de propósito:** De processador em lote para ferramenta de teste e depuração de caso específico

### dependenciesExtractor3.rb → dependenciesExtractor4.rb
- **Remoção de dependências:** Eliminação dos requires `csv` e `logger`, simplificando as dependências do script
- **Melhoria na estrutura de dados:** Alteração de strings para arrays Ruby (`%w[]`) para listas de arquivos, melhorando a legibilidade
- **Relatório formatado:** Substituição da saída CSV por um relatório bem formatado no console com seções organizadas
- **Tratamento robusto de erros Git:**
  - Verificação de repositórios corrompidos com recuperação automática
  - Validação da existência de commits antes do checkout
  - Mensagens de status informativas durante a execução
- **Remoção da função `clean_string`:** Não mais necessária devido ao uso de arrays ao invés de strings

### dependenciesExtractor4.rb → dependenciesExtractorForTAITIr.rb
- **Renomeação final:** Consolidação da versão 4 como versão final com nome mais descritivo
- **Código idêntico:** Nenhuma alteração funcional, apenas padronização do nome do arquivo