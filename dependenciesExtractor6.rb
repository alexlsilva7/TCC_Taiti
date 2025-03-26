require 'json'
require 'pathname'

class DependenciesExtractor

  def preprocess(target_project)
    command = "rubrowser --json \"#{target_project}\""
    puts "Running: #{command} and capturing output..."
    # Captura stdout. stderr (onde os avisos do Bundler podem ir) ainda irá para o console.
    rubrowser_output = `#{command}`

    # Verifica o status de saída do comando
    unless $?.success?
      # Inclui a saída capturada na mensagem de erro para diagnóstico
      raise "Failed to run rubrowser (Exit Status: #{$?.exitstatus}). Is it installed and in your PATH? Output/Error was:\n#{rubrowser_output}"
    end

    if rubrowser_output.nil? || rubrowser_output.strip.empty?
        # Se o comando teve sucesso mas não produziu saída, é um problema
        raise "rubrowser ran successfully but produced no output."
    end

    puts "rubrowser finished successfully, output captured."
    return rubrowser_output
  end

  # REMOVIDO: extract(output_path)
  # REMOVIDO: process()

  # Modificado para receber json_data (Hash)
  def find_all_relations(project_path, json_data, file_paths)
    response = ''
    file_path_arr = file_paths.split(",")

    # Verifica se json_data é válido (Hash não vazio)
    unless json_data.is_a?(Hash) && (!json_data['definitions'].nil? || !json_data['relations'].nil?)
        puts "Error: Invalid or empty JSON data provided to find_all_relations."
        return ""
    end

    file_path_arr.each do |file_path|
      # file_path aqui é absoluto vindo de add_home_path
      dependency_def = find_definition(json_data, file_path, "file") # Passa json_data
      if dependency_def != 'Not found'
        # Passa project_path e json_data para a próxima função
        response += find_formated_relations(project_path, json_data, file_path)
      else
        # É normal não encontrar definição para arquivos que não definem classes/módulos (e.g., views puras)
        # Mas pode ser útil logar se for inesperado.
        puts "Info: Definition not found for file: #{file_path}"
      end
    end

    # Tratamento mais seguro para a string de resposta
    return response.chomp(',').split(',').uniq.join(",")
  end

  # Modificado para receber json_data (Hash)
  def find_formated_relations(project_path, json_data, file_path)
    relations = find_relations(json_data, file_path) # Passa json_data
    response = ''
    project_pathname = Pathname.new(project_path) # Cria Pathname para o projeto base

    if relations != 'Not found'
      normalized_file_path = file_path.gsub(/\\/, '/')
      relations_for_file = relations[normalized_file_path] || relations[file_path]

      if relations_for_file
        relations_arr = relations_for_file.uniq { |t| t['namespace'] }

        relations_arr.each do |relation|
          path_definition_result = find_definition(json_data, relation['namespace'], "namespace") # Passa json_data

          if path_definition_result != 'Not found'
            # A chave é o namespace em minúsculas
            definition_entry = path_definition_result[relation['namespace'].downcase]

            if definition_entry && definition_entry[0] && definition_entry[0]['file']
              absolute_dependency_path_str = definition_entry[0]['file']
              # Certifica que o caminho do JSON seja tratado como absoluto se necessário
              # (Rubrowser geralmente gera caminhos absolutos)
              absolute_dependency_path = Pathname.new(File.expand_path(absolute_dependency_path_str))

              begin
                # Verifica se o caminho da dependência está dentro do projeto
                if absolute_dependency_path.to_s.start_with?(project_pathname.to_s)
                   relative_path = absolute_dependency_path.relative_path_from(project_pathname).to_s
                   response += relative_path + ','
                else
                    puts "Warning: Dependency path #{absolute_dependency_path} is outside the project path #{project_pathname}. Skipping relative path calculation."
                    # Opcional: adicionar caminho absoluto ou apenas pular
                end
              rescue ArgumentError => e
                puts "Warning: Could not determine relative path for #{absolute_dependency_path_str} from #{project_pathname}. Error: #{e.message}"
              end
            else
               puts "Warning: Definition found for namespace '#{relation['namespace']}', but file information is missing or invalid."
            end
          else
            # Pode ser normal se a dependência for de uma gem externa não analisada
            puts "Info: Definition not found for depended namespace: #{relation['namespace']}"
          end
        end
      else
         puts "Warning: No relations found in the loaded data for the key: #{normalized_file_path} or #{file_path}"
      end
    end
    response
  end

  # Modificado para receber json_data (Hash)
  def find_relations(json_data, file_path)
    dep = Hash.new
    search_file_norm = file_path.gsub(/\\|\//, '').downcase

    (json_data["relations"] || []).each do |dependency|
      if dependency["file"] && !dependency["file"].empty?
        dep_file_norm = dependency["file"].gsub(/\\|\//, '').downcase
        if dep_file_norm == search_file_norm
          original_dep_file = dependency["file"].gsub(/\\/, '/')
          dep[original_dep_file] ||= []
          dep[original_dep_file].push(dependency)
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  # Modificado para receber json_data (Hash)
  def find_definition(json_data, search_param, attribute)
    dep = Hash.new
    search_param_norm = search_param.to_s.gsub(/\\|\//, '').downcase

    (json_data["definitions"] || []).each do |definition|
      # Garante que a definição e o atributo existem antes de processar
      if definition && definition[attribute] && !definition[attribute].empty?
        def_attr_norm = definition[attribute].to_s.gsub(/\\|\//, '').downcase
        if def_attr_norm == search_param_norm
           # Usa o atributo original em minúsculas como chave para consistência
           original_key = definition[attribute].downcase
           dep[original_key] ||= []
           dep[original_key].push(definition)
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  # Modificado: Orquestra a captura, extração, parse e busca de relações.
  def get_all_dependencies(project_path, file_paths)
    # 1. Executa rubrowser --json e captura a saída bruta
    begin
      raw_output = preprocess(project_path)
    rescue => e
      puts "Error during preprocessing (running rubrowser): #{e.message}"
      return ""
    end

    # 2. Encontra o início do JSON na saída bruta
    json_start_index = raw_output.index('{')
    unless json_start_index
      puts "Error: Could not find the start of JSON data ('{') in rubrowser output."
      # Opcional: Mostrar a saída bruta para depuração (pode ser grande)
      # puts "Raw rubrowser output:\n#{raw_output}"
      return ""
    end

    # Extrai a porção que *deveria* ser JSON
    json_data_string = raw_output[json_start_index..-1]

    # 3. Parseia a string JSON para um Hash
    json_data = nil
    begin
      json_data = JSON.parse(json_data_string)
      puts "Successfully parsed JSON data."
    rescue JSON::ParserError => e
      puts "Error parsing JSON data extracted from rubrowser: #{e.message}"
      # Tenta dar uma dica sobre onde o erro pode estar
      context_size = 50
      error_context_start = [0, e.message.scan(/\d+/).map(&:to_i).min - context_size].max rescue 0
      error_context_end = error_context_start + (2 * context_size)
      puts "Problematic JSON string snippet around potential error:\n...#{json_data_string[error_context_start...error_context_end]}..."
      return ""
    end

    # 4. Encontra as relações usando o Hash JSON parseado
    return find_all_relations(project_path, json_data, file_paths)
  end
end

# add_home_path permanece igual
def add_home_path(home_path, testi_array)
  testi_array.map do |file_path|
    cleaned_path = file_path.strip
    File.expand_path(File.join(home_path, cleaned_path))
  end.join(',')
end

def main
  # --- CONFIGURAÇÃO ---
  local_project_path = "/home/alex/Área de trabalho/TCC_Taiti_LINUX_TEST/TestInterfaceEvaluation/spg_repos/bsmi" # <--- MUDE SE NECESSÁRIO

  unless Dir.exist?(local_project_path)
      puts "ERRO: O diretório do projeto especificado não existe: #{local_project_path}"
      return
  end
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
  begin
    current_path = local_project_path
    puts "Analisando projeto local em: #{current_path}"

    testi_files = add_home_path(current_path, taiti_data['TestI'])
    
    puts "Arquivos TestI a serem analisados: #{taiti_data['TestI'].count} arquivos."

    extractor = DependenciesExtractor.new
    dependencies = extractor.get_all_dependencies(current_path, testi_files)

    # --- EXIBIR RESULTADOS ---
    puts "\n" + "="*50
    puts " Relatório de Dependências ".center(50, '=')
    puts " Projeto: #{current_path} ".center(50, '=')
    puts "="*50

    puts "\nArquivos Identificados (TestI - relativos):"
    taiti_data['TestI'].each { |f| puts "  • #{f}" }

    puts "\nDependências Encontradas (TestIDep - caminhos relativos ao projeto):"
    if dependencies.empty?
        puts "  • Nenhuma dependência encontrada ou erro durante o processo."
    else
        # Ordena e imprime cada dependência em uma nova linha
        dependencies.split(',').sort.each { |d| puts "  • #{d}" }
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