require 'json'
require 'pathname'

class DependenciesExtractor

  # Variáveis de instância para armazenar dados pré-processados
  attr_reader :project_path, :definitions_by_file, :definitions_by_namespace, :relations_by_file

  # Helper privado para normalização consistente
  private def normalize_key(key_string)
    key_string.to_s.gsub(/\\|\//, '').downcase
  end

  def preprocess(target_project)
    command = "rubrowser --json \"#{target_project}\""
    puts "Running: #{command} and capturing output..."
    rubrowser_output = `#{command}`
    unless $?.success?
      raise "Failed to run rubrowser (Exit Status: #{$?.exitstatus}). Is it installed and in your PATH? Output/Error was:\n#{rubrowser_output}"
    end
    if rubrowser_output.nil? || rubrowser_output.strip.empty?
        raise "rubrowser ran successfully but produced no output."
    end
    puts "rubrowser finished successfully, output captured."
    return rubrowser_output
  end

  # Pré-processa o JSON criando hashes de lookup
  private def build_lookup_hashes(json_data)
    @definitions_by_file = Hash.new { |h, k| h[k] = [] }
    @definitions_by_namespace = Hash.new { |h, k| h[k] = [] }
    @relations_by_file = Hash.new { |h, k| h[k] = [] }

    (json_data["definitions"] || []).each do |definition|
      if definition && definition['file'] && !definition['file'].empty?
         # Usa caminho normalizado como chave, armazena definição original
        @definitions_by_file[normalize_key(definition['file'])] << definition
      end
      if definition && definition['namespace'] && !definition['namespace'].empty?
         # Usa namespace normalizado (minúsculo) como chave
        @definitions_by_namespace[definition['namespace'].downcase] << definition
      end
    end

    (json_data["relations"] || []).each do |relation|
      if relation && relation['file'] && !relation['file'].empty?
        @relations_by_file[normalize_key(relation['file'])] << relation
      end
    end
    puts "Lookup hashes built."
  end

  def find_all_relations(absolute_file_paths) # Recebe array de caminhos absolutos
    all_dependency_paths = [] # Coleta resultados em um array

    unless @definitions_by_file && @relations_by_file && @definitions_by_namespace
        puts "Error: Lookup hashes not built. Cannot find relations."
        return ""
    end

    absolute_file_paths.each do |abs_file_path|
      # Busca a definição do arquivo de entrada usando o lookup hash
      norm_file_key = normalize_key(abs_file_path)
      if @definitions_by_file.key?(norm_file_key)
        # Encontra relações formatadas (retorna um array de paths relativos)
        all_dependency_paths.concat(find_formated_relations(abs_file_path))
      else
        puts "Info: Definition not found for input file: #{abs_file_path}"
      end
    end

    # Processa o array final: achata (se necessário), remove duplicatas, ordena e junta
    return all_dependency_paths.flatten.uniq.sort.join(",")
  end

  def find_formated_relations(absolute_file_path)
    found_relative_paths = []
    project_pathname = Pathname.new(@project_path)
    norm_file_key = normalize_key(absolute_file_path)

    # Busca relações usando o lookup hash
    relations_for_file = @relations_by_file[norm_file_key]

    if relations_for_file && !relations_for_file.empty?
      # Pega namespaces únicos das relações encontradas
      unique_namespaces = relations_for_file.map { |r| r['namespace'] }.uniq

      unique_namespaces.each do |namespace|
        next if namespace.nil? # Pula se namespace for nil

        # Busca definição do namespace dependente usando o lookup hash
        norm_namespace_key = namespace.downcase
        definition_entries = @definitions_by_namespace[norm_namespace_key]

        if definition_entries && !definition_entries.empty?
          definition_entry = definition_entries.first

          if definition_entry['file'] && !definition_entry['file'].empty?
            absolute_dependency_path_str = definition_entry['file']
            absolute_dependency_path = Pathname.new(File.expand_path(absolute_dependency_path_str))

            begin
              if absolute_dependency_path.to_s.start_with?(project_pathname.to_s)
                 relative_path = absolute_dependency_path.relative_path_from(project_pathname).to_s
                 found_relative_paths << relative_path # Adiciona ao array
              else
                  puts "Warning: Dependency path #{absolute_dependency_path} is outside the project path #{project_pathname} (for namespace #{namespace}). Skipping."
              end
            rescue ArgumentError => e
              puts "Warning: Could not determine relative path for #{absolute_dependency_path_str} from #{project_pathname}. Error: #{e.message}"
            end
          else
             puts "Warning: Definition found for namespace '#{namespace}', but file information is missing."
          end
        else
          puts "Info: Definition not found for depended namespace: #{namespace} (referenced by #{absolute_file_path})"
        end
      end
    else
      puts "Warning: No relations found in lookup hash for key: #{norm_file_key} (file: #{absolute_file_path})"
    end
    found_relative_paths # Retorna o array de paths relativos encontrados para este arquivo
  end

  def get_all_dependencies(project_path_param, absolute_file_paths)
    @project_path = project_path_param # Armazena project_path como var de instância

    # 1. Preprocess
    begin
      raw_output = preprocess(@project_path)
    rescue => e
      puts "Error during preprocessing (running rubrowser): #{e.message}"
      return ""
    end

    # 2. Extract JSON String
    json_start_index = raw_output.index('{')
    unless json_start_index
      puts "Error: Could not find the start of JSON data ('{') in rubrowser output."
      return ""
    end
    json_data_string = raw_output[json_start_index..-1]

    # 3. Parse JSON
    json_data = nil
    begin
      json_data = JSON.parse(json_data_string)
      puts "Successfully parsed JSON data."
    rescue JSON::ParserError => e
      puts "Error parsing JSON data extracted from rubrowser: #{e.message}"
      puts "Problematic JSON string snippet might be near the end or contain invalid syntax."
      return ""
    end

    begin
      build_lookup_hashes(json_data)
    rescue => e
      puts "Error building lookup hashes from JSON data: #{e.message}"
      puts e.backtrace.join("\n")
      return ""
    end

    return find_all_relations(absolute_file_paths)
  end
end

def add_home_path(home_path, testi_array) # Adiciona o caminho do home ao array de arquivos TestI
  testi_array.map do |file_path|
    cleaned_path = file_path.strip
    File.expand_path(File.join(home_path, cleaned_path))
  end
end

def main
  local_project_path = "/home/alex/Área de trabalho/TCC_Taiti_LINUX_TEST/TestInterfaceEvaluation/spg_repos/bsmi" # <--- MUDE SE NECESSÁRIO

  unless Dir.exist?(local_project_path)
      puts "ERRO: O diretório do projeto especificado não existe: #{local_project_path}"
      return
  end
  local_project_path = File.expand_path(local_project_path)

  testi_files_relative = %w[
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
  
  begin
    current_path = local_project_path
    puts "Analisando projeto local em: #{current_path}"

    # add_home_path retorna um Array de caminhos absolutos
    testi_files_absolute = add_home_path(current_path, testi_files_relative)
    puts "Arquivos TestI a serem analisados: #{testi_files_absolute.count} arquivos."

    extractor = DependenciesExtractor.new
    # Passa o array de caminhos absolutos
    dependencies_string = extractor.get_all_dependencies(current_path, testi_files_absolute)

    # --- EXIBIR RESULTADOS ---
    puts "\n" + "="*50
    puts " Relatório de Dependências ".center(50, '=')
    puts " Projeto: #{current_path} ".center(50, '=')
    puts "="*50

    puts "\nArquivos Identificados (TestI - relativos):"
    testi_files_relative.each { |f| puts "  • #{f}" }

    puts "\nDependências Encontradas (TestIDep - caminhos relativos ao projeto):"
    if dependencies_string.empty?
        puts "  • Nenhuma dependência encontrada ou erro durante o processo."
    else
        # A string já vem formatada e ordenada
        dependencies_string.split(',').each { |d| puts "  • #{d}" }
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