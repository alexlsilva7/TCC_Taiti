require 'json'
require 'csv'
require 'git'
require 'fileutils'
require 'logger'

$log = Logger.new('logs.log')
class DependenciesExtractor

  def preprocess(target_project)
    output_path = Dir.pwd + '/TestInterfaceEvaluation/output.html' 
    Dir.chdir(target_project){
      `rubrowser > "#{output_path}"`
    }
  end

  def process()
    output_path = Dir.pwd + '/TestInterfaceEvaluation/output.html'
    dependencies_path = Dir.pwd + '/TestInterfaceEvaluation/dependencies.json'
    extract(output_path)
    if !File.zero?(dependencies_path)
      hashJ = JSON.parse(read_file(dependencies_path))
      write_file(hashJ.to_json, dependencies_path)
    end
  end

  def extract(output_path)
    file_content = read_file(output_path)
    dependencies_path = Dir.pwd + '/TestInterfaceEvaluation/dependencies.json'
    json_regex = /var data = (.*);/
    json_data = ""
    if !json_regex.match(file_content).nil?
      json_data = json_regex.match(file_content)[1]
    end
    write_file(json_data, dependencies_path)
  end

  def find_all_relations(file_paths)
    response = ''
    file_path_arr = file_paths.split(",")
    file_path_arr.each do |file_path|
      dependency_def = find_definition(file_path, "file")
      if dependency_def != 'Not found'
        response += find_formated_relations(file_path)
      end
    end
    return (response[0..-2]).split(',').uniq.join(",")
  end

  def find_formated_relations(file_path)
    relations = find_relations(file_path)
    response = ''
    if relations != 'Not found'
      if !file_path.nil?
        relations_arr = relations[file_path.gsub(/\\/.to_s, '/'.to_s)].uniq { |t| t['namespace'] }
      end
      relations_arr.each do |relation|
        path = find_definition(relation['namespace'], "namespace")
        if path != 'Not found'
          actual_path = Dir.pwd + 'TestInterfaceEvaluation/spg_repos/'
          k = actual_path.length + 1
          while(path[relation['namespace'].downcase][0]['file'][k] != '/')
            k += 1
          end
          response += path[relation['namespace'].downcase][0]['file'][k+1..-1] + ','
        end
      end
    end
    #Return comes with extra ',' take care
    response
  end

  def find_relations(file_path)
    dependencies_path = Dir.pwd + '/TestInterfaceEvaluation/dependencies.json'
    json = JSON.parse(read_file(dependencies_path))
    dep = Hash.new
    json["relations"].each do |dependency|
      if !dependency["file"].nil? && !file_path.nil?
        if dependency["file"].gsub(/\\|\//.to_s, ''.to_s).downcase == file_path.gsub(/\\|\//.to_s, ''.to_s).downcase
          dep["#{dependency["file"]}"] ? dep["#{dependency["file"]}"].push(dependency) : dep["#{dependency["file"]}"] = [dependency]
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  def find_definition(search_param, attribute)
    dependencies_path = Dir.pwd + '/TestInterfaceEvaluation/dependencies.json'
    json = JSON.parse(read_file(dependencies_path))
    dep = Hash.new
    json["definitions"].each do |definition|
      if !definition[attribute].nil? && !search_param.nil?
        if definition[attribute].gsub(/\\|\//.to_s, ''.to_s).to_s.downcase == search_param.gsub(/\\|\//.to_s, ''.to_s).to_s.downcase
          dep["#{definition[attribute]}"] ? dep["#{definition[attribute]}"].push(definition) : dep["#{definition[attribute]}".downcase] = [definition]
        end
      end
    end
    dep.empty? ? 'Not found' : dep
  end

  def read_file(path)
    File.open(path, 'rb') { |file| file.read }
  end

  def write_file(text, path)
    File.open(path, 'w') do |f|
      f.write text
    end
  end

  def get_all_dependencies(project_path, file_paths)
    preprocess(project_path)
    process()
    dependencies_path = Dir.pwd + '/TestInterfaceEvaluation/dependencies.json'
    
    if !File.zero?(dependencies_path)
      $log.debug{'Dependencies path nao esta vazio!'}
      return find_all_relations(file_paths)
    else
      $log.warn{'Dependencies path está vazio!'}
      return ""
    end
  end
end

def add_home_path(home_path, testi)
  correct_string = testi[1..-2]
  testi_new = correct_string.split(',')
  final_string = ''
  string_aux = ''
  testi_new.length.times do |k|
    i = 0
    while(testi_new[k][i] == ' ')
      i += 1
    end
    j = testi_new[k].length - 1
    while(testi_new[k][j] == ' ')
      j -= 1
    end
    fix_path = testi_new[k][i..j]
    string_aux = home_path + fix_path
    if(k != testi_new.length - 1)
      final_string = final_string + string_aux + ','
    else
      final_string = final_string + string_aux
    end
  end
  return final_string
end

def clean_string(testi)
  correct_string = testi[1..-2]
  testi_new = correct_string.split(',')
  final_string = ''
  string_aux = ''
  testi_new.length.times do |k|
    i = 0
    while(testi_new[k][i] == ' ')
      i += 1
    end
    j = testi_new[k].length - 1
    while(testi_new[k][j] == ' ')
      j -= 1
    end
    fix_path = testi_new[k][i..j]
    string_aux = fix_path
    if(k != testi_new.length - 1)
      final_string = final_string + string_aux + ','
    else
      final_string = final_string + string_aux
    end
  end
  return final_string
end

def main(taiti_result, task_csv)
  # Criar estrutura de diretórios se não existir
  FileUtils.mkdir_p('TestInterfaceEvaluation/spg_repos') unless Dir.exist?('TestInterfaceEvaluation/spg_repos')
  
  table_taiti = CSV.parse(File.read(taiti_result), headers: true)
  table_task = CSV.parse(File.read(task_csv), headers: true)
  #TODO Checar se arquivo existe, caso exista limpar ele antes de escrever para não pegar lixo junto
  CSV.open("testidep.csv", "wb") do |csv|
    csv << (table_taiti.headers + ['TestIDep']) 
    table_taiti.each.with_index do |row, i|
      begin
        name = table_task[i]['REPO_URL'].split('/')[-1][0..-5]
        $log.debug{'Executing Code to Get All Dependencies of Repo:' + name}
        dir = 'TestInterfaceEvaluation/spg_repos/' + name
        if(Dir.exist?(dir))
          begin
            git = Git.open(dir)
          rescue ArgumentError => e
            $log.error{"Erro ao abrir repositório: #{e.message}"}
            FileUtils.rm_rf(dir) if Dir.exist?(dir)
            git = Git.clone(table_task[i]['REPO_URL'], name, path: 'TestInterfaceEvaluation/spg_repos')
          end
        else
          git = Git.clone(table_task[i]['REPO_URL'], name, path: 'TestInterfaceEvaluation/spg_repos')
          #Needed for git windows, some cases may cause bug for checkout
          git.config('core.protectNTFS', 'false')
        end
        
        begin
          git.checkout(table_task[i]['LAST'])
          
          current_path = Dir.pwd + '/'+dir + '/'
          testi = add_home_path(current_path, table_taiti[i]['TestI'])
          testi_string = table_taiti[i]['TestI'][1..-2]
          all_dependencies = DependenciesExtractor.new.get_all_dependencies(current_path, testi)
          if all_dependencies != ""
            resultado = '[' + table_taiti[i]['TestI'][1..-2] + ','+all_dependencies + ']'
          else
            $log.warn "Todas as Dependencias vazias ID: " + table_taiti[i]['Task']
            resultado = '[' + table_taiti[i]['TestI'][1..-2] + ']'
          end
          csv << (row.fields + [resultado]) 
        rescue Git::GitExecuteError => e
          $log.error{"Erro ao fazer checkout: #{e.message}"}
          # Adiciona uma linha vazia ou com informação de erro no CSV
          csv << (row.fields + ["ERRO"])
        end
      rescue => e
        $log.error{"Erro geral: #{e.message}"}
        csv << (row.fields + ["ERRO GERAL"])
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  main(ARGV[0], ARGV[1])
end