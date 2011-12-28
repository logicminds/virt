module Virt::VMWare
  class Guest < Virt::Guest

    def initialize options = {}
      super(options)
      @volume        = Volume.new options
      @interface   ||= Interface.new options
      # If no volumes are defined create a new one for new vms
      if @volumes.length < 1
        # required in the vol name name/name
        options[:name] += "/#{options[:name]}"
        @volumes << Volume.new(options)
      end
      # Keep the first disk in @volume for legacy purposes
      if @volumes.length > 0
        @volume = @volumes[0]
      end
    end

    def save
      # need to create the volume first for vmware
      @volume.save if ( @volume)
      # Make sure the volume is created before we create the VM
      if ( @volume )
        @domain = @connection.connection.define_domain_xml(xml)
      end
      if (@domain)
        # this is an ungly hack to get around a bug in libvirt
        # where libvirt generates a mac address and ESX generates
        # a 2nd mac address after the vm is started.
        # By starting the vm we let ESX create the mac address 
        # and then capture it
        self.start
        self.poweroff
        fetch_info
      end
      !new?
    end

    def delete
      destroy
      # remove all volumes from pool and remove all volume objects
      for i in 0..@volumes.length 
        @volumes.delete_at(i) if @volumes[i].delete
      end
      new?
    end

    protected
    def to_volume(options = {})
      # this is required in order to create a vmware specific volume
      Volume.new(options)
    end
    
    def fetch_interfaces(network_type)
      # this is required in order to create a vmware specific interface
      unless network_type.nil?
        @interface       ||= Interface.new
        @interface.type    = network_type
        @interface.mac     = document("domain/devices/interface/mac", "address")
        @interface.device  = document("domain/devices/interface/source", network_type)
        @interface.model   = document("domain/devices/interface/model", "type")
      end
    end

    def default_template_path
      "vmware/guest.xml.erb"
    end
    
  end
end
