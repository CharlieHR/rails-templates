# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<-RUBY
    gem 'devise'

    gem 'autoprefixer-rails', '10.2.5'
    gem 'simple_form'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  RUBY
end

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

# Assets
########################################
run 'rm -rf vendor'
run 'rm app/assets/stylesheets/application.css'
run 'touch app/assets/stylesheets/application.scss'
inject_into_file 'app/assets/stylesheets/application.scss' do
  <<~CSS
    @import "bootstrap/scss/bootstrap";
  CSS
end
# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Layout
########################################
gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>")

style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)

# README
########################################
markdown_file_content = <<-MARKDOWN
Rails app generated with [charliehr/rails-templates](https://github.com/charliehr/rails-templates), created by the [CharlieHR engineering](https://www.charliehr.com/about) team.
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install', '--bootstrap')

  # Replace simple form initializer to work with Bootstrap 5
  run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + tean_member
  ########################################
  generate('devise:install')
  generate('devise', 'TeamMember')

  # Company model
  rails_command 'generate model Company'

  inject_into_file 'app/models/company.rb', before: 'end' do
    <<~RUBY
      has_many :team_members
    RUBY
  end

  inject_into_file 'app/models/team_member.rb', before: 'end' do
    <<~RUBY
      belongs_to :company
    RUBY
  end


  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_team_member!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'

  # Webpacker / Yarn
  ########################################
  run 'yarn add bootstrap @popperjs/core'
  run "rails webpacker:install:stimulus"
  append_file 'app/javascript/packs/application.js', <<~JS
    import "bootstrap"
  JS

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');
    JS
  end

  # Dotenv
  ########################################
  run 'touch .env'
end
