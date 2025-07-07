<h1 align="center">TCC Taiti</h1>
<p align="center">Projeto para receber saída de Taiti e encontrar as dependências estáticas</p>

### Pré-requisitos

Ruby version: 2.7.5<br/>
Ruby gems: 

- rubrowser: 2.11
- git: 1.10.2
-   : 1.4.1
- csv: 3.1.2
- json: 2.3.0
- parser: 3.1.0.0, 2.3.1.4, 2.3.1.2

Também é necessário os arquivos csv para rodar o código: Um csv com a saída de TAITI e outro csv com as hashes de commit da task<br/>
Exemplo dos arquivos está na root do repositório: taiti_result.csv(Saída de TAITI) e tasks_taiti.csv(csv com as hashes de commit da task)

### 🎲 Rodando o Codigo
```bash
Basta executar o script ruby passando os nomes dos arquivos csv, deve ser executado na root do projeto.

O csv com resultado de TAITI primeiro e depois o csv com o as hashes de commit.
Exemplo: 
ruby dependenciesExtractor.rb taiti_result.csv tasks_taiti.csv

O exemplo foi feito em windows, caso a máquina seja linux executar:
./dependenciesExtractor.rb taiti_result.csv tasks_taiti.csv

Para executar os arquivos cujos resultados foram apresentados no texto do TCC basta executar os arquivos na root do projeto do github:
No exemplo com 950 tarefas
./dependenciesExtractor.rb taiti_result950.csv tasks_950.csv
No exemplo com 437 tarefas
./dependenciesExtractor.rb taiti_result437.csv tasks_437.csv

```

## 🔄 Evolução do Script - Integração com TAITIr

O script original `dependenciesExtractor.rb` passou por uma série de refatorações que culminaram na versão `dependenciesExtractorForTAITIr.rb`, especificamente desenvolvida para integração com o plugin TAITIr.

### Principais Melhorias Implementadas:

- **Remoção de dependências desnecessárias**: Eliminação das gems `csv` e `logger` para simplificar a integração
- **Tratamento robusto de erros**: Implementação de verificações avançadas para operações Git e recuperação automática de repositórios corrompidos
- **Interface aprimorada**: Mudança de saída CSV para relatório formatado no console, facilitando a integração com o plugin TAITIr
- **Código de teste embutido**: Dados de teste integrados para facilitar a validação durante o desenvolvimento

### Script para Integração TAITIr

O arquivo `dependenciesExtractorForTAITIr.rb` representa a versão final otimizada para integração com o plugin TAITIr, oferecendo:

- **Execução simplificada**: Menos dependências externas
- **Melhor debugging**: Relatórios detalhados e mensagens de status
- **Maior confiabilidade**: Tratamento de erros robusto para operações Git
- **Manutenibilidade**: Código mais limpo e estruturado

Para executar essa nova versão:
```bash
ruby dependenciesExtractorForTAITIr.rb
```
