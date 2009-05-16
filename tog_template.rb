# app name
app_name = @root.split('/').last

if yes?("Drop databases?")
  run "mysqladmin -u root -p drop #{app_name}_development -f"
  run "mysqladmin -u root -p drop #{app_name}_test -f"
  run "mysqladmin -u root -p drop #{app_name}_production -f"
end

if yes?("Create databases?")
  # Create databases
  run "mysqladmin -u root -p create #{app_name}_development"
  run "mysqladmin -u root -p create #{app_name}_test"
  run "mysqladmin -u root -p create #{app_name}_production"
end

run "gem sources -a http://gems.github.com"

# Remove unnecessary files
puts "Removing unnecessary application files..."
run "rm README"
run "rm doc/README_FOR_APP"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
 
# Initialize a git repository
puts "Initializing an empty Git repository for SCM..."
git :init
# Set up .gitignore files
puts "Establishing files to ignore from Git repository..."
file ".gitignore", <<-END
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
END
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"

# Reload plugins
run "sed -i config/environment.rb -e \"s/Rails::Initializer.run do |config|/Rails::Initializer.run do |config|\\n\\tconfig.reload_plugins = true if RAILS_ENV == 'development'/\""

# Install gems
run "sed -i config/environment.rb -e \"s/Rails::Initializer.run do |config|/require 'desert'\\nRails::Initializer.run do |config|/\""
gem 'desert', :version => '0.5', :lib => 'desert'
gem 'mislav-will_paginate', :version => '~> 2.3.6', :lib => 'will_paginate', :source => 'http://gems.github.com'
gem 'tog-tog', :version => '0.4.4', :lib => 'tog'
rake "gems:install", :sudo => true

# Install plugins
puts "Installing plugins..."
# Exception Notifier
plugin 'exception_notifier', :git => 'git://github.com/rails/exception_notification.git'
run "sed -i app/controllers/application_controller.rb -e \"s/ActionController::Base/ActionController::Base\\n\\tinclude ExceptionNotifiable/\""
initializer 'exception_notifier_configs.rb',
%{ExceptionNotifier.exception_recipients = %w(erdoss@gmail.com)
ExceptionNotifier.email_prefix = "[#{app_name}] " }
plugin 'acts_as_commentable', :svn => "http://juixe.com/svn/acts_as_commentable"
file "db/migrate/" + Time.now.strftime("%Y%m%d%H%M%S") + "_acts_as_commentable.rb",
%q{class ActsAsCommentable < ActiveRecord::Migration
  def self.up
    create_table "comments", :force => true do |t|
      t.column "title", :string, :limit => 50, :default => "" 
      t.column "comment", :text, :default => "" 
      t.column "created_at", :datetime, :null => false
      t.column "commentable_id", :integer, :default => 0, :null => false
      t.column "commentable_type", :string, :limit => 15, :default => "", :null => false
      t.column "user_id", :integer, :default => 0, :null => false
    end
    add_index "comments", ["user_id"], :name => "fk_comments_user" 
  end
  def self.down
    drop_table :comments
  end
end
}
# Validates Non Offensiveness Of
plugin 'validates_non_offensiveness_of', :git => "git://github.com/cauta/validates_non_offensiveness_of.git"
# Acts As State Machine
plugin 'acts_as_state_machine', :svn => "http://elitists.textdriven.com/svn/plugins/acts_as_state_machine/trunk"
# Acts As Rateable
plugin 'acts_as_rateable', :git => "git://github.com/andry1/acts_as_rateable.git"
file "db/migrate/" + Time.now.strftime("%Y%m%d%H%M%S") + "_add_ratings.rb",
%q{class AddRatings < ActiveRecord::Migration
    def self.up
    create_table :ratings do |t|
            t.column :rating, :integer    # You can add a default value here if you wish
            t.column :rateable_id, :integer, :null => false
            t.column :rateable_type, :string, :null => false
    end
    add_index :ratings, [:rateable_id, :rating]    # Not required, but should help more than it hurts
    end
    def self.down
    drop_table :ratings
    end
end
}
# Seo Urls
plugin 'seo_urls', :svn => "http://svn.redshiftmedia.com/svn/plugins/seo_urls"
# Paperclip
plugin 'paperclip', :git => "git://github.com/thoughtbot/paperclip.git"
# Acts As Abusable
plugin 'acts_as_abusable', :git => "git://github.com/linkingpaths/acts_as_abusable.git"
generate "acts_as_abusable_migration"
# Acts As Taggable On Steroids
plugin 'acts_as_taggable_on_steroids', :svn => "http://svn.viney.net.nz/things/rails/plugins/acts_as_taggable_on_steroids"
generate "acts_as_taggable_migration"
# Acts As Scribe
plugin 'acts_as_scribe', :git => "git://github.com/linkingpaths/acts_as_scribe.git"
generate "acts_as_scribe_migration"
# Viking
plugin 'viking', :git => "git://github.com/technoweenie/viking.git"

# Install Tog plugins
plugin 'tog_user', :git => "git://github.com/cauta/tog_user.git"
plugin 'tog_core', :git => "git://github.com/cauta/tog_core.git"
plugin 'tog_social', :git => "git://github.com/cauta/tog_social.git"
plugin 'tog_mail', :git => "git://github.com/cauta/tog_mail.git"

# Add Tog routes
route "map.routes_from_plugin 'tog_user'"
route "map.routes_from_plugin 'tog_core'"
route "map.routes_from_plugin 'tog_mail'"
route "map.routes_from_plugin 'tog_social'"

# Create Tog migrations
file "db/migrate/" + Time.now.strftime("%Y%m%d%H%M%S") + "_install_tog.rb",
%q{class InstallTog < ActiveRecord::Migration
    def self.up
      migrate_plugin "tog_user", 1
      migrate_plugin "tog_core", 6
      migrate_plugin "tog_social", 5
      migrate_plugin "tog_mail", 2
    end
    def self.down
      migrate_plugin "tog_mail", 0 
      migrate_plugin "tog_social", 0 
      migrate_plugin "tog_core", 0
      migrate_plugin "tog_user", 0
    end
end
}

# Tog rake tasks
run "echo \"require 'tasks/tog'\" >> Rakefile"

# Migrate
rake "db:migrate"

if yes?("Install Tog Conversatio?")
  gem "RedCloth", :lib => "redcloth", :source => "http://code.whytheluckystiff.net"
  rake "gems:install", :sudo => true
  plugin 'thinking-sphinx', :git => "git://github.com/freelancing-god/thinking-sphinx.git"
  plugin 'tog_conversatio', :git => "git://github.com/cauta/tog_conversatio.git"
  route "map.routes_from_plugin 'tog_conversatio'"
  file "db/migrate/" + Time.now.strftime("%Y%m%d%H%M%S") + "_install_tog_conversatio.rb",
  %q{class InstallTogConversatio < ActiveRecord::Migration
      def self.up
        migrate_plugin "tog_conversatio", 5
      end

      def self.down
        migrate_plugin "tog_conversatio", 0 
      end
  end
  }
  rake "db:migrate"
  rake "thinking_sphinx:index"
end

if yes?("Install Tog Picto?")
  plugin 'acts_as_list', :git => "git://github.com/rails/acts_as_list.git"
  plugin 'tog_picto', :git => "git://github.com/cauta/tog_picto.git"
  route "map.routes_from_plugin 'tog_picto'"
  file "db/migrate/" + Time.now.strftime("%Y%m%d%H%M%S") + "_install_tog_picto.rb",
  %q{class InstallTogPicto < ActiveRecord::Migration
    def self.up
      migrate_plugin "tog_picto", 7
    end

    def self.down
      migrate_plugin "tog_picto", 0
    end
  end
  }
  rake "db:migrate"
  rake "thinking_sphinx:index"
end

rake "tog:plugins:copy_resources"

if yes?("Run tog's tests?")
  rake "db:test:prepare"
  rake "tog:plugins:test"
end

# Create the first repository commit
git :add => '.'
git :commit => "-a -m 'Initial commit'"
