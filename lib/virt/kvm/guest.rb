module Virt::KVM
  class Guest < Virt::Guest

    def initialize options = {}
      super(options)
      @interface   ||= Interface.new options
      # If no volumes are defined create a new one for new vms
      if @volumes.length < 1
        # required in the vol name name/name
        @volumes << Volume.new(options)
      end
      # Keep the first disk in @volume for legacy purposes
      if @volumes.length > 0
        @volume = @volumes[0]
      end
    end
    
    protected
    
    def default_template_path
      "kvm/guest.xml.erb"
    end
    
    def to_volume(options = {})
      Volume.new(options)
    end  

  end
end
