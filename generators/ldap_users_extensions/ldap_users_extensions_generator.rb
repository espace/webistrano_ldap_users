class LdapUsersExtensionsGenerator < Rails::Generator::Base
  
  def manifest
    #added files
    record do |m|
	m.migration_template 'add_ldap_cn_to_users.rb', 'db/migrate', :migration_file_name => "add_ldap_cn_to_users"
      
     m.gsub_file 'app/models/user.rb', /(#{Regexp.escape("require 'digest/sha1'")})/mi do |match|
        "#{match}\n
	require 'rubygems'\n
	require 'net/ldap'\n"
      end

     m.gsub_file 'app/models/user.rb', /(#{Regexp.escape("class User < ActiveRecord::Base")})/mi do |match|
        "#{match}\n
	attr_accessible :ldap_cn\n
	def self.retrieve_from_ldap(login)\n
		ldap = Net::LDAP.new  :host => WebistranoConfig[:ldap_host], :port => WebistranoConfig[:ldap_port], :base => WebistranoConfig[:ldap_base]\n
		filter = Net::LDAP::Filter.eq('cn', login)\n
		ldap_entry = ldap.search(:filter => filter).first\n
		return ldap_entry\n
	end\n
	def ldap_authenticated?(password)\n
		ldap = Net::LDAP.new  :host => WebistranoConfig[:ldap_host], :port => WebistranoConfig[:ldap_port], :base => WebistranoConfig[:ldap_base]\n
		ldap_entry = User.retrieve_from_ldap(ldap_cn)\n
		dn=ldap_entry.dn\n
		ldap.auth(dn,password)\n
		ldap.bind\n
	end\n
	def self.ldap_users\n
		ldap = Net::LDAP.new  :host => WebistranoConfig[:ldap_host], :port => WebistranoConfig[:ldap_port], :base => WebistranoConfig[:ldap_base]\n
		entries = ldap.search()\n
		entries.delete_if{|u| u[:cn] == []}\n
		return entries\n
	end\n
	def self.ldap_email(ldap_cn)\n
		ldap = Net::LDAP.new  :host => WebistranoConfig[:ldap_host], :port => WebistranoConfig[:ldap_port], :base => WebistranoConfig[:ldap_base]\n
		filter = Net::LDAP::Filter.eq('cn', ldap_cn)\n
		ldap_entry = ldap.search(:filter => filter).first\n
		return ldap_entry[:mail].to_s\n
	end\n
	def normalize\n
		if self.login.blank?\n
			self.login = self.ldap_cn\n
			self.email = User.ldap_email(self.ldap_cn)\n
			if(self.email.blank?)\n
				self.email = \"\#{self.login}@empty.com\"\n
			end\n 
			self.password = '----'\n
			self.password_confirmation = '----'\n
		else\n
			self.ldap_cn = nil\n
		end\n
	end\n"
      end
     m.gsub_file 'app/models/user.rb', /(#{Regexp.escape("u && u.authenticated?(password) ? u : nil")})/mi do |match|
        "u && (u.authenticated?(password) || u.ldap_authenticated?(password)) ? u : nil"
      end
     m.gsub_file 'app/controllers/users_controller.rb', /(#{Regexp.escape("@user = User.new(params[:user])")})/mi do |match|
        "#{match}\n@user.normalize\n"
      end


     m.gsub_file 'app/controllers/users_controller.rb', /def edit\s+\@user = User.find\(params\[:id\]\)/mi do |match|
        "#{match}\n
	if !@user.ldap_cn.blank?\n
    		@user.login = nil\n
    		@user.email = nil\n
	end\n"
      end

	m.gsub_file 'app/controllers/users_controller.rb', /(#{Regexp.escape("@user.attributes = params[:user]")})/mi do |match|
        "#{match}\n@user.normalize\n"
      	end

	#webistrano_config
	#24
	m.gsub_file 'config/webistrano_config.rb', /(#{Regexp.escape("WebistranoConfig = {")})/mi do |match|
		"#{match}\n 
		:ldap_host => \"192.168.0.5\",\n
		:ldap_port => 389,\n
		:ldap_base => \"ou=people,dc=example,dc=com\",\n"
	end	
  		
      
      #18
      m.template 'views/_form.html.erb', 'app/views/users/_form.html.erb'
    
    end
  end
  
end
