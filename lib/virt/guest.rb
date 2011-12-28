module Virt
  class Guest
    include Virt::Util
    attr_reader :name, :xml_desc, :arch, :current_memory, :type, :boot_device, :machine
    attr_accessor :memory, :vcpu, :volume, :interface, :template_path

    def initialize options = {}
      @connection = Virt.connection
      @host = @connection.host
      @name = options[:name] || raise("Must provide a name")
      @staticstate = nil
      # we will need the libvirt domain object to retreive the information
      # since we already created the object in the host class we can just use the cache to retreive it
      if @name and @host
      	@domain = @host.libvirtcache[@name]
      end
      # If our domain exists, we ignore the provided options and defaults
      fetch_guest
      @memory ||= options[:memory] || default_memory_size
      @vcpu   ||= options[:vcpu]   || default_vcpu_count
      @arch   ||= options[:arch]   || default_arch

      @template_path = options[:template_path] || default_template_path
    end

    def new?
      @domain.nil?
    end

    def save
      @domain = @connection.connection.define_domain_xml(xml)
      fetch_info
      !new?
    end

    def start
      raise "Guest not created, can't start" if new?
      @domain.create unless running?
      running?
    end

    def running?(static=false)
      # 0 = nostate
      # 1 = running
      # 2 = blocked on resource
      # 3 = domain is paused
      # 4 = being shut down
      # 5 = domain is shut off
      # http://www.libvirt.org/html/libvirt-libvirt.html#virDomainState
      return false if new?
      # use the staticstate for non-realtime state lookups (each lookup cost about 10-20 ms)
      if !static or @staticstate.nil?
        # causes find entity by UUID in ESX
        # this will cache the current state for future lookups
        @staticstate = @domain.info.state
      end
      return @staticstate == 1
      
    rescue
      # some versions of libvirt do not support checking for active state
      @connection.connection.list_domains.each do |did|
        return true if @connection.connection.lookup_domain_by_id(did).name == name  
      end
      false
    end

    def stop(force=false)
      raise "Guest not created, can't stop" if new?
      force ? @domain.destroy : @domain.shutdown
      !running?
    rescue Libvirt::Error
      # domain is not running
      true
    end

    def shutdown
      stop
    end

    def poweroff
      stop(true)
    end

    def destroy
      return true if new?
      stop(true) if running?
      @domain = @domain.undefine
      new?
    end

    def reboot
      raise "Guest not running, can't reboot" if new? or !running?
      @domain.reboot
    end

    def uuid
      @domain.uuid unless new?
    end

    def to_s
      name.to_s
    end

    def <=> other
      self.name <=> other.name
    end

    protected

    def fetch_guest
     if @domain.nil?
        # this is done if only the name was passed in
        @domain = @connection.connection.lookup_domain_by_name(name)
        # cache the results
        @host.libvirtcache[@domain.name] = @domain
     end
     fetch_info
   rescue Libvirt::RetrieveError
    end

    def fetch_info
      return if @domain.nil?
      @xml_desc       = @domain.xml_desc
      @memory         = @domain.max_memory
      @current_memory = document("domain/currentMemory") if running?
      @type           = document("domain", "type")
      @vcpu           = document("domain/vcpu")
      @arch           = document("domain/os/type", "arch")
      @machine        = document("domain/os/type", "machine")
      @boot_device    = document("domain/os/boot", "dev") rescue nil

      # do we have a NIC?
      network_type = document("domain/devices/interface", "type") rescue nil

      unless network_type.nil?
        @interface       ||= Interface.new
        @interface.type    = network_type
        @interface.mac     = document("domain/devices/interface/mac", "address")
        @interface.device  = document("domain/devices/interface/source", "bridge")  if @interface.type == "bridge"
        @interface.network = document("domain/devices/interface/source", "network") if @interface.type == "network"
     end
    end

    def default_memory_size
      1048576
    end

    def default_vcpu_count
      1
    end

    def default_arch
      "x86_64"
    end

    def default_template_path; end
  end
end
