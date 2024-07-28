#!/bin/bash

# Versão do Script
SCRIPT_VERSION="2.0.3"

# Variáveis
PROJECT_DIR="my_project"
MIGRATIONS_DIR="migrations"
DB_NAME="my_project_db"
DB_USER="victorguedes"  # Altere conforme necessário
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
echo "Criando a estrutura de diretórios..."
create_directory "$PROJECT_DIR"

# Navega para o diretório do projeto
cd "$PROJECT_DIR" || { echo "Erro: Não foi possível entrar no diretório $PROJECT_DIR"; exit 1; }

create_directory "$MIGRATIONS_DIR"
create_directory "app/models"
create_directory "app/controllers"
create_directory "app/use_cases"

# Cria o Gemfile
echo "Criando o Gemfile..."
create_file "Gemfile"
write_to_file "Gemfile" \
"source 'https://rubygems.org'

gem 'sinatra'
gem 'sequel'
gem 'pg'
gem 'rake'
gem 'rackup'
gem 'sinatra-sequel'"

# Instala as dependências
echo "Instalando dependências..."
bundle install || { echo "Erro: Falha ao instalar dependências"; exit 1; }

# Cria o arquivo config.ru
echo "Criando o config.ru..."
create_file "config.ru"
write_to_file "config.ru" \
"require 'sinatra'
require 'sinatra/sequel'

# Configuração do banco de dados
Sequel.connect(ENV['DATABASE_URL'] || 'postgres://victorguedes@localhost/my_project_db')

# Carrega os controladores e modelos após a conexão com o banco
require './app/controllers/samples_controller'
require './app/controllers/results_controller'
Dir.glob('./app/models/*.rb').each { |file| require file }

run Sinatra::Application"

echo "Criando o console.rb..."
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
echo "Criando o Rakefile..."
create_file "Rakefile"
write_to_file "Rakefile" \
"require 'sequel'
require 'rake'
require 'sinatra/sequel'

namespace :db do
  task :create do
    begin
      db = Sequel.connect('postgres://$DB_USER@localhost/postgres')
      unless db['SELECT 1 FROM pg_database WHERE datname = ?', '$DB_NAME'].any?
        db.run('CREATE DATABASE $DB_NAME')
        puts 'Banco de dados criado com sucesso. Versão: $SCRIPT_VERSION'
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
      db = Sequel.connect('postgres://$DB_USER@localhost/postgres')
      db.run('DROP DATABASE IF EXISTS $DB_NAME')
      puts 'Banco de dados excluído com sucesso. Versão: $SCRIPT_VERSION'
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
      db = Sequel.connect('postgres://$DB_USER@localhost/$DB_NAME')
      Sequel.extension :migration
      Sequel::Migrator.run(db, 'migrations')
      puts 'Migrations aplicadas com sucesso. Versão: $SCRIPT_VERSION'
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
    migration_dir = 'migrations'
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

# Cria as migrations
echo "Criando migrations..."
create_migration_file "001_create_samples.rb" \
"Sequel.migration do
  change do
    create_table :samples do
      primary_key :id
      String :name
      Integer :age
      String :sex
    end
  end
end"
echo "Migration 001_create_samples.rb criada com sucesso. Versão: $SCRIPT_VERSION"

create_migration_file "002_create_exames.rb" \
"Sequel.migration do
  change do
    create_table :exames do
      primary_key :id
      String :name
    end
  end
end"
echo "Migration 002_create_exames.rb criada com sucesso. Versão: $SCRIPT_VERSION"

create_migration_file "003_create_equipamentos.rb" \
"Sequel.migration do
  change do
    create_table :equipamentos do
      primary_key :id
      String :name
      String :configuration
    end
  end
end"
echo "Migration 003_create_equipamentos.rb criada com sucesso. Versão: $SCRIPT_VERSION"

create_migration_file "004_create_exame_samples.rb" \
"Sequel.migration do
  change do
    create_table :exame_samples do
      foreign_key :sample_id, :samples
      foreign_key :exame_id, :exames
      primary_key [:sample_id, :exame_id]
    end
  end
end"
echo "Migration 004_create_exame_samples.rb criada com sucesso. Versão: $SCRIPT_VERSION"

create_migration_file "005_create_equipamento_exame_params.rb" \
"Sequel.migration do
  change do
    create_table :equipamento_exame_params do
      primary_key :id
      foreign_key :exame_id, :exames
      foreign_key :equipamento_id, :equipamentos
      String :depara_env
      String :depara_rcb
    end
  end
end"
echo "Migration 005_create_equipamento_exame_params.rb criada com sucesso. Versão: $SCRIPT_VERSION"

create_migration_file "006_create_resultados.rb" \
"Sequel.migration do
  change do
    create_table :resultados do
      primary_key :id
      foreign_key :sample_id, :samples
      foreign_key :exame_id, :exames
      foreign_key :exame_sample_id, :exame_samples
      foreign_key :equipamento_id, :equipamentos
      foreign_key :equipamento_exame_params_id, :equipamento_exame_params
      Float :value
    end
  end
end"
echo "Migration 006_create_resultados.rb criada com sucesso. Versão: $SCRIPT_VERSION"

# Aplica as migrations
# echo "Aplicando migrations..."
# bundle exec rake db:migrate || { echo "Erro: Falha ao aplicar as migrations"; exit 1; }
# echo "Configuração do projeto concluída com sucesso. Versão: $SCRIPT_VERSION"

# Cria os modelos
echo "Criando modelos..."
create_file "app/models/sample.rb"
write_to_file "app/models/sample.rb" \
"require 'sequel'

class Sample < Sequel::Model
  many_to_many :exames, join_table: :exames_samples, unique: true 
  one_to_many :resultados
end"
echo "Modelo sample.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/models/exame.rb"
write_to_file "app/models/exame.rb" \
"require 'sequel'

class Exame < Sequel::Model
  many_to_many :samples, join_table: :exames_samples, unique: true 
  one_to_many :resultados
end"
echo "Modelo exame.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/models/exame_sample.rb"
write_to_file "app/models/exame_sample.rb" \
"require 'sequel'

class ExameSample < Sequel::Model
  many_to_one :sample
  many_to_one :exame
  one_to_many :resultados
end"
echo "Modelo exame_sample.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/models/equipamento.rb"
write_to_file "app/models/equipamento.rb" \
"require 'sequel'

class Equipamento < Sequel::Model
  one_to_many :equipamento_exame_params
  one_to_many :resultados
end"
echo "Modelo equipamento.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/models/equipamento_exame_params.rb"
write_to_file "app/models/equipamento_exame_params.rb" \
"require 'sequel'

class EquipamentoExameParams < Sequel::Model
  many_to_one :exame
  many_to_one :equipamento
  one_to_many :resultados
end"
echo "Modelo equipamento_exame_params.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/models/resultado.rb"
write_to_file "app/models/resultado.rb" \
"require 'sequel'

class Resultado < Sequel::Model
  many_to_one :sample
  many_to_one :exame
  many_to_one :exame_sample
  many_to_one :equipamento
  many_to_one :equipamento_exame_params
end"
echo "Modelo resultado.rb criado com sucesso. Versão: $SCRIPT_VERSION"

# Cria os controllers
echo "Criando controllers..."
create_file "app/controllers/samples_controller.rb"
write_to_file "app/controllers/samples_controller.rb" \
"require 'sinatra'
require 'json'
require_relative '../models/sample'
require_relative '../models/exame'
require_relative '../models/exame_sample'

class SamplesController < Sinatra::Base
  post '/samples' do
    request_data = JSON.parse(request.body.read)
    sample = Sample.create(name: request_data['name'], age: request_data['age'], sex: request_data['sex'])
    request_data['exames'].each do |exame_id|
      SampleExame.create(sample_id: sample.id, exame_id: exame_id)
    end
    sample.to_json
  end
end"
echo "Controller samples_controller.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/controllers/results_controller.rb"
write_to_file "app/controllers/results_controller.rb" \
"require 'sinatra'
require 'json'
require_relative '../models/resultado'

class ResultsController < Sinatra::Base
  post '/results' do
    request_data = JSON.parse(request.body.read)
    Resultado.create(
      sample_id: request_data['sample_id'],
      exame_sample_id: request_data['exame_sample_id'],
      equipamento_id: request_data['equipamento_id'],
      param_name: request_data['param_name'],
      param_value: request_data['param_value'],
      created_at: Time.now,
      updated_at: Time.now
    )
    status 201
  end
end"
echo "Controller results_controller.rb criado com sucesso. Versão: $SCRIPT_VERSION"

# Cria os use cases
echo "Criando use cases..."
create_file "app/use_cases/create_sample.rb"
write_to_file "app/use_cases/create_sample.rb" \
"require_relative '../models/sample'
require_relative '../models/exame_sample'

module UseCases
  class CreateSample
    def initialize(params)
      @params = params
    end

    def call
      sample = Sample.create(name: @params[:name], age: @params[:age], sex: @params[:sex])
      @params[:exames].each do |exame_id|
        SampleExame.create(sample_id: sample.id, exame_id: exame_id)
      end
      sample
    end
  end
end"
echo "Use case create_sample.rb criado com sucesso. Versão: $SCRIPT_VERSION"

create_file "app/use_cases/create_result.rb"
write_to_file "app/use_cases/create_result.rb" \
"require_relative '../models/resultado'

module UseCases
  class CreateResult
    def initialize(params)
      @params = params
    end

    def call
      Resultado.create(
        sample_id: @params[:sample_id],
        exame_sample_id: @params[:exame_sample_id],
        equipamento_id: @params[:equipamento_id],
        param_name: @params[:param_name],
        param_value: @params[:param_value],
        created_at: Time.now,
        updated_at: Time.now
      )
    end
  end
end"
echo "Use case create_result.rb criado com sucesso. Versão: $SCRIPT_VERSION"

echo "Configuração do projeto concluída com sucesso. Versão: $SCRIPT_VERSION"

