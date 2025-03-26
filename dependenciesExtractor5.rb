require 'json'
require 'fileutils'
require 'pathname'

class DependenciesExtractor

  def preprocess(target_project)
    output_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'output.html')
    # Garante que o diretório de saída exista
    FileUtils.mkdir_p(File.dirname(output_path))
    puts "Running rubrowser in: #{target_project}"
    puts "Outputting to: #{output_path}"
    # Usar system ou backticks. Backticks capturam a saída, system é melhor se não precisar dela.
    # Adicionar tratamento de erro para rubrowser
    success = system("rubrowser \"#{target_project}\" > \"#{output_path}\"")
    unless success
      raise "Failed to run rubrowser. Is it installed and in your PATH?"
    end
    puts "rubrowser finished."
  end

  def extract(output_path)
    dependencies_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'dependencies.json')
    # Garante que o diretório de saída exista
    FileUtils.mkdir_p(File.dirname(dependencies_path))

    # Verifica se o output.html foi criado
    unless File.exist?(output_path)
      raise "Error: rubrowser output file not found at #{output_path}. Preprocessing might have failed."
    end
    # Verifica se o output.html não está vazio
    if File.zero?(output_path)
        puts "Warning: rubrowser output file is empty at #{output_path}."
        write_file("{}", dependencies_path) # Escreve um JSON vazio para evitar erros posteriores
        return # Sai da extração
    end

    file_content = read_file(output_path)
    json_regex = /var data = (\{.*?\});/m # Regex ajustada para multiline e não gulosa
    json_data = "{}" # Default para JSON vazio se não encontrar

    match = json_regex.match(file_content)
    if match && match[1]
      json_data = match[1]
      puts "Successfully extracted JSON data from rubrowser output."
    else
      puts "Warning: Could not find 'var data = {...};' in #{output_path}. dependencies.json will be empty."
    end
    write_file(json_data, dependencies_path)
  end

  def process()
    output_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'output.html')
    dependencies_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'dependencies.json')
    extract(output_path) # Chama extract que agora tem mais verificações
    # Verifica se dependencies.json existe antes de tentar ler
    if File.exist?(dependencies_path) && !File.zero?(dependencies_path)
      begin
        hashJ = JSON.parse(read_file(dependencies_path))
        # Apenas reescreve se o parse foi bem-sucedido
        write_file(JSON.pretty_generate(hashJ), dependencies_path) # Usar pretty_generate para legibilidade
      rescue JSON::ParserError => e
        puts "Error parsing dependencies.json: #{e.message}. Leaving the file as is."
        # Opcional: deletar ou renomear o arquivo inválido
        # File.delete(dependencies_path)
      end
    else
        puts "Warning: dependencies.json is missing or empty after extraction."
    end
  end

  # Modificado para receber project_path
  def find_all_relations(project_path, file_paths)
    response = ''
    file_path_arr = file_paths.split(",")
    dependencies_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'dependencies.json')

    # Verifica se o arquivo de dependências existe e não está vazio
    unless File.exist?(dependencies_path) && !File.zero?(dependencies_path)
        puts "Error: Cannot find relations because dependencies.json is missing or empty."
        return ""
    end

    # Carrega o JSON uma vez
    begin
        json_data = JSON.parse(read_file(dependencies_path))
    rescue JSON::ParserError => e
        puts "Error parsing dependencies.json in find_all_relations: #{e.message}"
        return "" # Retorna vazio se não conseguir parsear
    end

    file_path_arr.each do |file_path|
      # file_path aqui é absoluto vindo de add_home_path
      dependency_def = find_definition(json_data, file_path, "file") # Passa json_data
      if dependency_def != 'Not found'
        # Passa project_path e json_data para a próxima função
        response += find_formated_relations(project_path, json_data, file_path)
      else
        puts "Warning: Definition not found for file: #{file_path}"
      end
    end

    # Tratamento mais seguro para a string de resposta
    return response.chomp(',').split(',').uniq.join(",")
  end

  # Modificado para receber project_path e json_data
  def find_formated_relations(project_path, json_data, file_path)
    relations = find_relations(json_data, file_path) # Passa json_data
    response = ''
    project_pathname = Pathname.new(project_path) # Cria Pathname para o projeto base

    if relations != 'Not found'
      # A chave em 'relations' deve corresponder ao 'file_path' absoluto
      # A normalização de barras pode ser necessária dependendo do rubrowser/OS
      normalized_file_path = file_path.gsub(/\\/, '/')
      relations_for_file = relations[normalized_file_path] || relations[file_path] # Tenta ambos

      if relations_for_file
        # Pega relações únicas pelo namespace
        relations_arr = relations_for_file.uniq { |t| t['namespace'] }

        relations_arr.each do |relation|
          # Busca a definição do namespace dependente
          path_definition_result = find_definition(json_data, relation['namespace'], "namespace") # Passa json_data

          if path_definition_result != 'Not found'
            # A definição pode ter múltiplas entradas, pegamos a primeira
            # A chave é o namespace em minúsculas
            definition_entry = path_definition_result[relation['namespace'].downcase]

            if definition_entry && definition_entry[0] && definition_entry[0]['file']
              absolute_dependency_path_str = definition_entry[0]['file']
              absolute_dependency_path = Pathname.new(absolute_dependency_path_str)

              # Calcula o caminho relativo da dependência em relação à raiz do projeto
              begin
                relative_path = absolute_dependency_path.relative_path_from(project_pathname).to_s
                response += relative_path + ','
              rescue ArgumentError => e
                # Isso pode acontecer se os caminhos estiverem em drives diferentes (Windows)
                # ou se o caminho da dependência não estiver dentro do project_pathname
                puts "Warning: Could not determine relative path for #{absolute_dependency_path_str} from #{project_pathname}. Error: #{e.message}"
                # Opcional: adicionar o caminho absoluto ou pular
                # response += absolute_dependency_path_str + ','
              end
            else
               puts "Warning: Definition found for namespace '#{relation['namespace']}', but file information is missing or invalid."
            end
          else
            puts "Warning: Definition not found for depended namespace: #{relation['namespace']}"
          end
        end
      else
         puts "Warning: No relations found in the loaded data for the key: #{normalized_file_path} or #{file_path}"
      end
    end
    response
  end

  # Modificado para receber json_data
  def find_relations(json_data, file_path)
    # json = JSON.parse(read_file(dependencies_path)) # REMOVIDO - JSON já carregado
    dep = Hash.new
    # Normaliza o file_path de busca
    search_file_norm = file_path.gsub(/\\|\//, '').downcase

    (json_data["relations"] || []).each do |dependency|
      if dependency["file"] && !dependency["file"].empty?
        # Normaliza o caminho da dependência no JSON
        dep_file_norm = dependency["file"].gsub(/\\|\//, '').downcase
        if dep_file_norm == search_file_norm
          # Usa o caminho original (não normalizado) como chave para preservar barras
          original_dep_file = dependency["file"].gsub(/\\/, '/') # Padroniza para /
          dep[original_dep_file] ||= []
          dep[original_dep_file].push(dependency)
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  # Modificado para receber json_data
  def find_definition(json_data, search_param, attribute)
    # json = JSON.parse(read_file(dependencies_path)) # REMOVIDO - JSON já carregado
    dep = Hash.new
    # Normaliza o parâmetro de busca
    search_param_norm = search_param.to_s.gsub(/\\|\//, '').downcase

    (json_data["definitions"] || []).each do |definition|
      if definition[attribute] && !definition[attribute].empty?
        # Normaliza o atributo da definição no JSON
        def_attr_norm = definition[attribute].to_s.gsub(/\\|\//, '').downcase
        if def_attr_norm == search_param_norm
           # Usa o atributo original em minúsculas como chave
           original_key = definition[attribute].downcase
           dep[original_key] ||= []
           dep[original_key].push(definition)
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  # read_file e write_file permanecem iguais
  def read_file(path)
    File.open(path, 'rb') { |file| file.read }
  end

  def write_file(text, path)
    File.open(path, 'w') do |f|
      f.write text
    end
  end

  # Modificado para passar project_path para find_all_relations
  def get_all_dependencies(project_path, file_paths)
    preprocess(project_path)
    process() # Process agora lida melhor com JSON vazio/inválido
    dependencies_path = File.join(Dir.pwd, 'TestInterfaceEvaluation', 'dependencies.json')

    if File.exist?(dependencies_path) && !File.zero?(dependencies_path)
      # Passa project_path para find_all_relations
      return find_all_relations(project_path, file_paths)
    else
      puts "Skipping relation finding as dependencies.json is missing or empty."
      return ""
    end
  end
end

# add_home_path permanece igual
def add_home_path(home_path, testi_array)
  testi_array.map do |file_path|
    cleaned_path = file_path.strip
    # Garante que o caminho resultante seja absoluto
    File.expand_path(File.join(home_path, cleaned_path))
  end.join(',')
end

def main
  # --- CONFIGURAÇÃO ---
  # !!! Defina o caminho absoluto para a raiz do seu projeto local aqui !!!
  local_project_path = "/home/alex/Área de trabalho/TCC_Taiti_LINUX_TEST/TestInterfaceEvaluation/spg_repos/bsmi" # <--- MUDE ISSO

  # Verifica se o caminho fornecido existe e é um diretório
  unless Dir.exist?(local_project_path)
      puts "ERRO: O diretório do projeto especificado não existe: #{local_project_path}"
      return # Sai do script se o caminho for inválido
  end
  # Garante que o caminho seja absoluto
  local_project_path = File.expand_path(local_project_path)

  taiti_data = {
    'TestI' => %w[
      app/controllers/mentor_teacher/schedules_controller.rb
      app/controllers/user_sessions_controller.rb
      app/helpers/mentor_teacher/schedules_helper.rb
      app/models/timeslot.rb
      app/models/user_session.rb
      app/views/mentor_teacher/schedules/_form.html.haml
      app/views/mentor_teacher/schedules/new.html.haml
      app/views/user_sessions/new.html.haml
      app/views/user_sessions/shared/_error_messages.html.erb
    ]
  }

  # --- EXECUÇÃO ---
  # Criar estrutura de diretórios de saída se não existir (MELHORADO)
  output_base_dir = File.join(Dir.pwd, 'TestInterfaceEvaluation')
  FileUtils.mkdir_p(output_base_dir) unless Dir.exist?(output_base_dir)

  begin
    # REMOVIDO: Bloco inteiro de clonagem/verificação de git

    # Usa o caminho local fornecido diretamente
    current_path = local_project_path
    puts "Analisando projeto local em: #{current_path}"

    # Cria caminhos absolutos para TestI baseado no caminho local
    testi_files = add_home_path(current_path, taiti_data['TestI'])
    puts "Arquivos TestI a serem analisados (absolutos):\n#{testi_files.split(',').join("\n  - ")}"


    extractor = DependenciesExtractor.new
    # Passa o caminho do projeto local para o extrator
    dependencies = extractor.get_all_dependencies(current_path, testi_files)

    # --- EXIBIR RESULTADOS ---
    puts "\n" + "="*50
    puts " Relatório de Dependências ".center(50, '=')
    puts " Projeto: #{current_path} ".center(50, '=')
    puts "="*50

    puts "\nArquivos Identificados (TestI):"
    taiti_data['TestI'].each { |f| puts "  • #{f}" }

    puts "\nDependências Encontradas (TestIDep - caminhos relativos ao projeto):"
    if dependencies.empty?
        puts "  • Nenhuma dependência encontrada ou erro na extração."
    else
        dependencies.split(',').sort.each { |d| puts "  • #{d}" } # Ordena para melhor visualização
    end
    puts "="*50

  rescue => e
    puts "\n" + " ERRO INESPERADO ".center(50, '=')
    puts "ERRO: #{e.message}"
    puts "Backtrace:".ljust(50, '-')
    puts e.backtrace.join("\n")
    puts "="*50
  end
end

if __FILE__ == $PROGRAM_NAME
  main
end