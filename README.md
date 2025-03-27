<h1 align="center">TCC Taiti</h1>
<p align="center">Projeto para receber saída de Taiti e encontrar as dependências estáticas</p>

---

**🚀 VERSÃO REATORADA DISPONÍVEL! 🚀**

**Existe uma versão mais nova, rápida e simplificada deste script!**

A versão refatorada (`dependenciesExtractor_refactored.rb`):

*   **Executa diretamente em projetos locais:** Não precisa mais clonar via Git.
*   **Usa argumentos de linha de comando:** Não depende mais de arquivos CSV para entrada.
*   **Mais Rápida:** Utiliza `rubrowser --json` e processamento em memória, eliminando arquivos intermediários.
*   **Dependências Simplificadas:** Requer apenas a gem `rubrowser`.
*   **Funciona em versões mais novas do Ruby:** Compatível com Ruby 3.3.0 e superior.

**É fortemente recomendado usar a versão refatorada para novas análises.**

➡️ **Consulte o arquivo `README_REFACTOR.md` para instruções de uso e detalhes da nova versão.**

---

### Pré-requisitos

Ruby version: 2.1.0 or higher<br/>
Ruby gems: rubrowser, git, fileutils, csv, json<br/><br/>
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

