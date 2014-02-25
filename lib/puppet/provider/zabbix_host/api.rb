# we need to monkey patch the 0.6.0 version of the zabbixapi to return interfaces

require 'zabbixapi'
require File.join(Gem.loaded_specs['zabbixapi'].full_gem_path, 'lib', 'zabbixapi', '2.0', 'basic', 'basic_alias.rb')
class ZabbixApi
  def interfaces
    @interfaces ||= Interfaces.new(@client)
  end

	class Hosts < Basic
		def get_full_data(data)
			#Puppet.debug "[DEBUG] Call get_full_data with parametrs: #{data.inspect}"
			@client.api_request(
				:method => "#{method_name}.get",
				:params => {
					:filter => {
						indentify.to_sym => data[indentify.to_sym]
						},
						:selectInterfaces => 'extend',
						:selectGroups => 'extend',
						:selectParentTemplates => 'extend',
						:output => "extend",
					}
				)
		end
		def merge_params(params)
			foo = JSON.generate(default_options.merge(params)).to_s
			JSON.parse(foo)
		end

		def update(data)
			Puppet.debug "testing"

			dump = {}
			item_id = data[key.to_sym].to_i
			dump_by_id(key.to_sym => data[key.to_sym]).each do |item|
				dump = symbolize_keys(item) if item[key].to_i == data[key.to_sym].to_i
			end

			if dump == data
				log "[DEBUG] Equal keys #{dump} and #{data}, skip update"
				Puppet.debug "[DEBUG] Equal keys " + dump.inspect + " and " + data.inspect + ", skip update"
				item_id
			else
				data_update = array_flag ? [data] : data
				Puppet.debug "updating"
				result = @client.api_request(:method => "#{method_name}.update", :params => data_update)
				parse_keys result
			end

		end

		def dump_by_id(data)
			log "[DEBUG] Call dump_by_id with parametrs: #{data.inspect}"

			@client.api_request(
				:method => "#{method_name}.get",
				:params => {
					:filter => {
						key.to_sym => data[key.to_sym]
						},
						:output => "extend",
						:selectInterfaces => 'extend'
					}
					)
		end
	end
 class Interfaces < Basic

    def array_flag
      true
    end

    def method_name
      "hostinterface"
    end

    def indentify
      "hostids"
    end

    def key
      "interfaceid"
    end
    def get_full_data(data)
      Puppet.debug "[DEBUG] Call get_full_data with parametrs: #{data.inspect}"

      @client.api_request(
        :method => "#{method_name}.get",
        :params => {
          indentify.to_sym => data[indentify.to_sym],
          :sortfield => "interfaceid",
          :output => "extend"
        }
      )
    end
    def get_id(data)
      Puppet.debug "[DEBUG] Call get_id with parametrs: #{data.inspect}"

      result = symbolize_keys( get_full_data(data) )
      Puppet.debug "[DEBUG] Result: #{result.inspect}"
      id = nil
      result.each { |item| id = item[key.to_sym].to_i }
      Puppet.debug "[DEBUG] ID is #{id.to_s}"
      id
    end


    def create_or_update(data)
      Puppet.debug "[DEBUG] Call interfaces.create_or_update with parametrs: #{data.inspect}"

      data[:interfaceid] ? update(data) : create(data)
    end

    def create(data)
      Puppet.debug "[DEBUG] Call create with parametrs: #{data.inspect}"
      hostinterface = []
      data_with_default = default_options.empty? ? data : merge_params(data)
      data_create = array_flag ? [data_with_default] : data_with_default
      result = @client.api_request(:method => "#{method_name}.create", :params => data_create)
      parse_keys result
    end

    def update(data)     
      Puppet.debug "[DEBUG] Call update with parametrs: #{data.inspect}"
      
      data_update = array_flag ? [data] : data
      result = @client.api_request(:method => "#{method_name}.update", :params => data_update)
      parse_keys result

    end




  end

end
Puppet::Type.type(:zabbix_host).provide(:api) do

	confine  :kernel => 'linux'

	def exists?
		@property_hash[:ensure] == :present
	end

	def self.instances
		instances = []
		moo = connect()
		moo2 = connect()
		foo = moo.hosts.get(:id => 0)
		foo.each do |host|
			Puppet.debug "Working on #{host.inspect}"
			attrs=['ip','useip','type','main','dns','port']
			groups=[]
			host['groups'].each do |group|
				groups << group['name']
			end
			templates=[]
			if host['parentTemplates'] != nil
				host['parentTemplates'].each do |template|
					templates << template['name']
				end
			end
			interfaces=[]
			existinginterfaces=[]
			host['interfaces'].each do |interfaceid, interface|
				existinginterfaces << interface	
			end
			existinginterfaces = existinginterfaces.sort_by { |k| k["interfaceid"].to_i }
			existinginterfaces.each do |interface|
				['hostid','interfaceid' ].each do |k|
  					interface.delete(k)
				end
				interfaces << interface
			end
			instance = new(:name => host['host'], :groups => groups.reverse, :templates => templates.reverse, :ensure => :present, :interfaces => interfaces, :hostid => host['hostid'])
			Puppet.debug "Instances: found instance #{instance.inspect}"
			instances << instance
		end
		instances
	end

	def self.prefetch(host)
		instances.each do |prov|
			if pkg = host[prov.name]
				pkg.provider = prov
			end
		end
	end

	def create
		moo = connect()
		groups = []
		templates = []
		@resource[:groups].each do |group|
			thegroup = moo.hostgroups.get_id(:name => group)
			unless thegroup.nil?
				groups << { :groupid => thegroup }
			end
		end
		@resource[:templates].each do |template|
			thetemplate = moo.templates.get_id(:host => template)
			unless thetemplate.nil?
				templates << { :templateid => thetemplate }
			end
		end

		#Puppet.debug groups.inspect
		#Puppet.debug templates.inspect
		Puppet.debug @resource[:interfaces].inspect
		moo.hosts.create_or_update(:host => @resource[:name], :groups => groups, :templates => templates, :interfaces => @resource[:interfaces])
	end

        def update
                moo = connect()
                groups = []
                templates = []
                templatesClear = []

                @resource[:groups].each do |group|
                        thegroup = moo.hostgroups.get_id(:name => group)
                        unless thegroup.nil?
                                groups << { :groupid => thegroup }
                        end
                end
                @resource[:templates].each do |template|
                        thetemplate = moo.templates.get_id(:host => template)
                        unless thetemplate.nil?
                                templates << { :templateid => thetemplate }
                        end
                end

				existingtemplates = moo.hosts.get(:host => @resource[:name])
				if ! existingtemplates[0].nil?
					host = existingtemplates[0]
					Puppet.debug "Got templates from API - Going to compare"
					Puppet.debug "Inspect: #{host.inspect}"
					host['parentTemplates'].each do |aTemplate|
						Puppet.debug "Working on template #{aTemplate['name']}"
						if @resource[:templates].detect {|template| template == aTemplate['name']}.nil?
							Puppet.debug "template #{aTemplate['name']} should be deleted"
							thetemplate = moo.templates.get_id(:host => aTemplate['name'])
							unless thetemplate.nil?
								templatesClear << { :templateid => thetemplate }
							end
						else
							Puppet.debug "template #{aTemplate['name']} should be left alone"
						end
					end
				end

                #Puppet.debug groups.inspect
                #Puppet.debug templates.inspect
                Puppet.debug @resource[:interfaces].inspect
                moo.hosts.create_or_update(:host => @resource[:name], :groups => groups, :templates => templates, :templates_clear => templatesClear)
        end


	def groups
		@property_hash[:groups]
	end
	def templates
		Puppet.debug "Asked about template: #{@property_hash[:templates]}"
		@property_hash[:templates]
	end
	def interfaces 
		@property_hash[:interfaces]
	end
	def hostid
		@property_hash[:hostid]
	end
	def groups=(foo)
		update()
	end
	def templates=(foo)
		Puppet.debug "Updating templates with #{foo.inspect}"
		update()
	end
	def interfaces=(foo)
                moo = connect()
                hostid = moo.hosts.get_id(:host => @resource[:name])
	        Puppet.debug "Trying to set interfaces for host"+hostid.to_s
		existinginterfaces = moo.interfaces.get_full_data(:hostids => hostid)
		i=0
		foo.each do |pInterface|
			Puppet.debug "hostInterface from Puppet #{pInterface.inspect}"
			Puppet.debug "hostInterface from API #{existinginterfaces[i].inspect}"
			if existinginterfaces[i] == nil
				Puppet.debug "Createing new interface"
				moo.interfaces.create_or_update(pInterface.merge(:hostid => hostid ))
			elsif pInterface['type'] != existinginterfaces[i]['type'] || pInterface['main'] != existinginterfaces[i]['main'] || pInterface['dns'] != existinginterfaces[i]['dns'] || pInterface['useip'] != existinginterfaces[i]['useip'] || pInterface['port'] != existinginterfaces[i]['port'] || pInterface['ip'] != existinginterfaces[i]['ip']
				Puppet.debug "hostInterface #{existinginterfaces[i]['interfaceid']} should be updated"
				#moo.interfaces.create_or_update(:interfaceid => existinginterfaces[i]['interfaceid'],:type => pInterface['type'], :port => pInterface['port'],:dns => pInterface['dns'])
				moo.interfaces.create_or_update(pInterface.merge(:interfaceid => existinginterfaces[i]['interfaceid']))
			end
			i += 1
		end
		if existinginterfaces.length > foo.length
			Puppet.debug "Still interfaces to delete"
			while i < existinginterfaces.length  do
				Puppet.debug "hostInterface #{existinginterfaces[i]['interfaceid']} should be deleted"
				moo.interfaces.delete(existinginterfaces[i]['interfaceid'])
				i += 1
			end
		end
		#moo.interfaces.create_or_update(:hostids => hostid, :interface => interface)
		
	end

	#  private 
	def self.connect
		credentials = YAML::load_file('/root/.zabbix')
		connect=ZabbixApi.connect( :url => "#{credentials['url']}/api_jsonrpc.php", :user => credentials['username'], :password => credentials['password'], :use_ssl => true )
		return connect
	end
	def connect
		credentials = YAML::load_file('/root/.zabbix')
		connect=ZabbixApi.connect( :url => "#{credentials['url']}/api_jsonrpc.php", :user => credentials['username'], :password => credentials['password'], :use_ssl => credentials['use_ssl'] )
		return connect
	end
end
