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

def main

  task_data = {
    'REPO_URL' => 'https://github.com/BTHUNTERCN/bsmi.git',
    'TASK_ID' => '31',
    'LAST' => 'd8437823ff9e718c172088a9bbc508d4ec58d34c',
    # Adicione outros campos necessários do tasks_taiti.csv aqui
  }

  taiti_data = {
    'Project' => 'https://github.com/BTHUNTERCN/bsmi',
    'Task' => '31',
    'Changed files' => '[app/assets/javascripts/mentor_teacher/schedules.js, app/models/timeslot.rb, app/views/mentor_teacher/schedules/_week_calendar.html.haml, app/controllers/mentor_teacher/schedules_controller.rb, app/assets/stylesheets/mentor_teacher/schedules.css.scss, app/helpers/mentor_teacher/schedules_helper.rb, app/views/mentor_teacher/schedules/edit_or_new.html.haml, app/views/mentor_teacher/schedules/show.html.haml, spec/controllers/mentor_teacher/schedules_controller_spec.rb, features/mentor_teacher_schedule.feature, features/step_definitions/bsmi_steps.rb, spec/factories/timeslot.rb, app/models/mentor_teacher.rb, spec/factories/cal_courses.rb, spec/models/mentor_teacher_spec.rb, app/controllers/cal_courses_controller.rb]',
    'TestI' => '[app/controllers/mentor_teacher/schedules_controller.rb, app/controllers/user_sessions_controller.rb, app/helpers/mentor_teacher/schedules_helper.rb, app/models/timeslot.rb, app/models/user_session.rb, app/views/mentor_teacher/schedules/_form.html.haml, app/views/mentor_teacher/schedules/new.html.haml, app/views/user_sessions/new.html.haml, app/views/user_sessions/shared/_error_messages.html.erb]'
  }

  # Criar estrutura de diretórios se não existir
  FileUtils.mkdir_p('TestInterfaceEvaluation/spg_repos') unless Dir.exist?('TestInterfaceEvaluation/spg_repos')
  
  CSV.open("testidep.csv", "wb") do |csv|
    csv << ['Project', 'Task', 'Changed files', 'TestI', 'TestIDep']
    
    begin
      name = task_data['REPO_URL'].split('/')[-1][0..-5]
      $log.debug{"Processing repository: #{name}"}
      dir = 'TestInterfaceEvaluation/spg_repos/' + name

      if Dir.exist?(dir)
        begin
          git = Git.open(dir)
        rescue ArgumentError => e
          FileUtils.rm_rf(dir)
          git = Git.clone(task_data['REPO_URL'], name, path: 'TestInterfaceEvaluation/spg_repos')
        end
      else
        git = Git.clone(task_data['REPO_URL'], name, path: 'TestInterfaceEvaluation/spg_repos')
        git.config('core.protectNTFS', 'false')
      end

      begin
        git.checkout(task_data['LAST'])
        
        current_path = File.join(Dir.pwd, dir, '/')
        testi = add_home_path(current_path, taiti_data['TestI'])
        
        dependencies = DependenciesExtractor.new.get_all_dependencies(current_path, testi)
        resultado = dependencies.empty? ? taiti_data['TestI'] : "#{taiti_data['TestI'][0...-1]},#{dependencies}]"

        csv << [
          taiti_data['Project'],
          taiti_data['Task'],
          taiti_data['Changed files'],
          taiti_data['TestI'],
          resultado
        ]

      rescue Git::GitExecuteError => e
        $log.error{"Checkout error: #{e.message}"}
        csv << [taiti_data['Project'], taiti_data['Task'], 'ERROR', 'ERROR', 'ERROR']
      end
    rescue => e
      $log.error{"General error: #{e.message}"}
      csv << [taiti_data['Project'], taiti_data['Task'], 'ERROR', 'ERROR', 'ERROR']
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  main
end