#!/bin/bash

# Versão do Script
SCRIPT_VERSION="2.0.3"

# Variáveis
PROJECT_DIR="my_project"
MIGRATIONS_DIR="db/migrations"
DB_NAME="my_project_db"
DB_USER= whoami # Altere conforme necessário
CURRENT_FOLDER=$(basename "$(pwd)")

# Função para criar diretórios e verificar se foram criados com sucesso
create_directory() {
  local dir_path=$1
  echo "Criando diretório $dir_path..."
  mkdir -p "$dir_path"
  if [ ! -d "$dir_path" ]; then
    echo "Erro: Não foi possível criar o diretório $dir_path"
    exit 1
  fi
}

# Função para criar arquivos
create_file() {
  local file_path=$1
  echo "Criando arquivo $file_path..."
  touch "$file_path"
  if [ ! -f "$file_path" ]; then
    echo "Erro: Não foi possível criar o arquivo $file_path"
    exit 1
  fi
}

# Função para escrever conteúdo em um arquivo
write_to_file() {
  local file_path=$1
  local content=$2
  echo "Escrevendo no arquivo $file_path..."
  echo "$content" > "$file_path"
  if [ $? -ne 0 ]; then
    echo "Erro: Não foi possível escrever no arquivo $file_path"
    exit 1
  fi
}

# Cria a estrutura de diretórios
create_directory "$PROJECT_DIR"

# Navega para o diretório do projeto
cd "$PROJECT_DIR" || { echo "Erro: Não foi possível entrar no diretório $PROJECT_DIR"; exit 1; }

create_directory "$MIGRATIONS_DIR"
create_directory "app/models"
create_directory "app/controllers"
create_directory "app/use_cases"
create_directory "app/serializers"
create_directory "config"

# Cria o Gemfile
create_file "Gemfile"
write_to_file "Gemfile" \
"source 'https://rubygems.org'

gem 'sinatra'
gem 'sequel'
gem 'pg'
gem 'rake'
gem 'rackup'
gem 'sinatra-sequel'
gem 'sinatra-contrib'"

# Instala as dependências
echo "Bundle vendor/bundle config set..."
bundle config set --local path 'vendor/bundle'

echo "Instalando dependências..."
bundle install || { echo "Erro: Falha ao instalar dependências"; exit 1; }

# Cria o arquivo config.ru
create_file "config.ru"
write_to_file "config.ru" \
"require './config/environment'

run Sinatra::Application"

create_file "console.rb"
write_to_file "console.rb" \
"require 'bundler/setup'  # Carrega as gems listadas no Gemfile
require 'sinatra'
require 'sinatra/sequel'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://victorguedes@localhost/my_project_db')

Dir.glob('./app/models/*.rb').each { |file| require file }
Dir.glob('./app/controllers/*.rb').each { |file| require file }

require 'irb'
IRB.start"

# Cria o arquivo Rakefile
create_file "Rakefile"
write_to_file "Rakefile" \
"require 'sequel'
require 'rake'
require 'sinatra/sequel'

namespace :db do
  task :create do
    begin
      db = Sequel.connect('postgres://victorguedes@localhost/postgres')
      unless db['SELECT 1 FROM pg_database WHERE datname = ?', 'my_project_db'].any?
        db.run('CREATE DATABASE my_project_db')
        puts 'Banco de dados criado com sucesso. Versão: 2.0.3'
      else
        puts 'Banco de dados já existe.'
      end
    rescue Sequel::DatabaseConnectionError => e
      puts 'Erro ao conectar ao banco de dados:'
      puts e.message
      exit 1
    rescue => e
      puts 'Erro ao criar o banco de dados:'
      puts e.message
      exit 1
    end
  end

  task :drop do
    begin
      db = Sequel.connect('postgres://victorguedes@localhost/postgres')
      db.run('DROP DATABASE IF EXISTS my_project_db')
      puts 'Banco de dados excluído com sucesso. Versão: 2.0.3'
    rescue Sequel::DatabaseConnectionError => e
      puts 'Erro ao conectar ao banco de dados:'
      puts e.message
      exit 1
    rescue => e
      puts 'Erro ao excluir o banco de dados:'
      puts e.message
      exit 1
    end
  end

  task :migrate do
    begin
      db = Sequel.connect('postgres://victorguedes@localhost/my_project_db')
      Sequel.extension :migration
      Sequel::Migrator.run(db, 'db/migrations')
      puts 'Migrations aplicadas com sucesso. Versão: 2.0.3'
    rescue Sequel::DatabaseConnectionError => e
      puts 'Erro ao conectar ao banco de dados:'
      puts e.message
      exit 1
    rescue => e
      puts 'Erro ao aplicar as migrations:'
      puts e.message
      exit 1
    end
  end

desc 'Generate a migration file with a sequential number and a custom name'
  task :generate_migration, [:name] do |t, args|
    # Verifica se o nome foi passado
    if args[:name].nil? || args[:name].empty?
      puts 'Erro: Você deve fornecer um nome para a migration.'
      exit 1
    end

    # Define o caminho do diretório de migrations
    migration_dir = 'db/migrations'
    FileUtils.mkdir_p(migration_dir) unless Dir.exist?(migration_dir)

    # Cria um arquivo de migration com um número sequencial
    migration_count = Dir.glob('#{migration_dir}/*.rb').count
    migration_number = format('%03d', migration_count + 1) # Garante que tenha 3 dígitos
    migration_file_name = '#{migration_number}_#{args[:name].gsub(' ', '_').downcase}.rb'
    migration_file_path = '#{migration_dir}/#{migration_file_name}'

    File.open(migration_file_path, 'w') do |file|
      file.puts 'Sequel.migration do'
      file.puts '  change do'
      file.puts '    # Adicione suas mudanças aqui'
      file.puts '  end'
      file.puts 'end'
    end

    puts 'Migration #{migration_file_path} criada com sucesso.'
  end
end"

create_file "readme.md"
write_to_file "README.MD" \
"https://sinatrarb.com/intro.html -> controllers

sequel -> https://github.com/jeremyevans/sequel/blob/master/doc/association_basics.rdoc

bundle exec 'rake db:task' -> executa rake

gems instaladas locais no vendor/bundle"

# Função para criar o banco de dados se não existir
create_database() {
  echo "Verificando se o banco de dados '$DB_NAME' existe..."
  psql -U $DB_USER -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1
  if [ $? -ne 0 ]; then
    echo "O banco de dados '$DB_NAME' não existe. Criando..."
    createdb -U $DB_USER $DB_NAME || { echo "Erro: Falha ao criar o banco de dados '$DB_NAME'"; exit 1; }
    echo "Banco de dados '$DB_NAME' criado com sucesso. Versão: $SCRIPT_VERSION"
  else
    echo "O banco de dados '$DB_NAME' já existe."
  fi
}

# Cria o banco de dados se não existir
create_database

# Cria as migrations
create_migration_file() {
  local migration_file=$1
  local migration_content=$2
  local full_path_file="$MIGRATIONS_DIR/$migration_file"
  echo "Criando migration $migration_file..."
  create_file "$full_path_file"
  write_to_file "$full_path_file" "$migration_content"
}

# Cria os controllers
create_file "app/controllers/example_controller.rb"
write_to_file "app/controllers/example_controller.rb" \
"require 'sinatra'
require 'json'
require_relative '../serializers/hello_serializer'

class ExampleController < ApplicationController
  get '/hello' do
    
    HelloSerialized = HelloSerializer.new('Hello World')
    json HelloSerialized.as_json
  end
end"
echo "Controller example_controller.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/controllers/application_controller.rb"
write_to_file "app/controllers/application_controller.rb" \
"require 'sinatra'
require 'json'
require_relative '../serializers/hello_serializer'

class ExampleController < ApplicationController
  get '/hello' do
    
    HelloSerialized = HelloSerializer.new('Hello World')
    json HelloSerialized.as_json
  end
end"
echo "Controller application_controller.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/controllers/hello_serializer.rb"
write_to_file "app/controllers/hello_serializer.rb" \
"class HelloSerializer
    def initialize(param)
    @param = param
    end

    def as_json(param = @param || "Vazio")
        { message: @param }
    end
end"

git init

echo "Serializer hello_serializer.rb criado com sucesso. Versão: $SCRIPT_VERSION"

echo "Configuração do projeto concluída com sucesso. Versão: $SCRIPT_VERSION"
