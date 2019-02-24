require 'fileutils'
require 'tempfile'
require 'byebug'

class String
  def to_camel()
    self.split("_").map{|w| w[0] = w[0].upcase; w}.join
  end
  def to_snake()
    self
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .tr("-", "_")
    .downcase
  end
end

def match_line?(line, target_name, target_version)
  if line =~ /^gem/
    line = line.strip.sub(/^gem /,"")
    src_name, src_version = line.split(",").map{ |v| v.strip }.map{ |v| v.gsub(/"|'/,"") }
    if src_name == target_name && src_version == target_version
      return true
    end
  end
end

def update_target?(gemfile_path, version_info_before)
  before_name    = version_info_before[:name]
  before_version = version_info_before[:version]

  result = false 
  fo = open(gemfile_path)
  while line = fo.gets
    if match_line?(line, before_name, before_version)
      result = true
      break
    end
  end
  fo.close

  result
end

def gemfile_update(gemfile_path, version_info_before, version_info_after)
  before_name    = version_info_before[:name]
  before_version = version_info_before[:version]
  after_name     = version_info_after[:name]
  after_version  = version_info_after[:version]

  tempfile = Tempfile.new
  fo = open(gemfile_path)
  while line = fo.gets
    if match_line?(line, before_name, before_version)
      tempfile.print "gem '#{after_name}', '#{after_version}'\n"
    else
      tempfile.print line
    end
  end
  fo.close
  tempfile.close

  FileUtils.cp(tempfile.path,gemfile_path)
end

def gemfile_backup(gemfile_path, backup_dir_path)
  FileUtils.mkdir_p(backup_dir_path)
  FileUtils.cp(gemfile_path, backup_dir_path)
end

def execute_git(script_name, commit_message)
  if Dir.exist?(".git")
    system("git add Gemfile")
    system("git commit -m \"#{commit_message}\"")
    if system('grep "\[remote \"origin\"\]" .git/config')
      system("git push")
    end
  end
end

def execute_gem_update
  if File.exist?("bin/bundle")
    system("bin/bundle install")
  else
    system("bundle install")
  end
end

def log(log_file_path, message)
  File.open(log_file_path, "a") do |f|
    if block_given?
      f.puts "[START] #{message}"
      yield
      f.puts "[END] #{message}"
    else
      f.puts message
    end
  end
end


# -----------------
# 設定 BEGIN
# -----------------
script_name = File.basename(__FILE__,".*")
log_file_path = "#{script_name}.log"
commit_message = "[Update] bootstrap-sass gem update by #{script_name}"
backup_root_dir_path = "#{script_name}_#{Time.now.strftime("%Y%m%d_%H%M%S")}"

version_info_before = { name: "bootstrap-sass", version: "3.3.7" }
version_info_after  = { name: "bootstrap-sass", version: "3.4.1" }
# -----------------
# 設定 END
# -----------------

target_project_path_list = []
ARGV.each do |arg|
  if FileTest.directory?(arg)
    target_project_path_list << arg
  end
end

target_project_path_list.each do |project_dir_path|
  backup_dir_path = File.join(backup_root_dir_path, project_dir_path)
  gemfile_path    = File.join(project_dir_path,"Gemfile")

  log(log_file_path, "=== CHECK STR #{project_dir_path} #{Time.now}")

  unless File.exist?(gemfile_path)
    log(log_file_path, "#{gimfile_path} => Not found Gemfile.")
    next
  end

  if update_target?(gemfile_path, version_info_before)
    log(log_file_path, "#{gemfile_path} => Update target!")

    log(log_file_path, "gemfile_backup #{gemfile_path} => #{backup_dir_path}") do
      gemfile_backup(gemfile_path, backup_dir_path)
    end

    log(log_file_path, "gemfile_update #{gemfile_path} => #{version_info_before.to_s} to #{version_info_after.to_s}") do
      gemfile_update(gemfile_path, version_info_before, version_info_after)
    end

    log(log_file_path, "execute_gem_update") do
      Dir.chdir(project_dir_path) do
        execute_gem_update()
      end
    end

    log(log_file_path, "execute_git") do
      Dir.chdir(project_dir_path) do
        execute_git(script_name, commit_message)
      end
    end
  else
    log(log_file_path, "#{gemfile_path} => Not target")
  end

  log(log_file_path, "=== CHECK END #{project_dir_path} #{Time.now}\n\n")

end
