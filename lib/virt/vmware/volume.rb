module Virt::VMWare
  class Volume < Virt::Volume

    def default_type
      "raw"
    end

    def default_template_path
      "vmware/volume.xml.erb"
    end

    def path
      # this may not work correctly if user changes name of vm
      # this file should only be used to create new a vm
      "[#{pool.name}] #{self}"
    end

    def name= name
      super name
      # add .vmdk uless it already is appended
      @name += ".vmdk" unless name.match(/.*\.vmdk$/)
    end

    def to_s
      "#{name}"
    end

    protected

    def title
      name.chomp(".vmdk")
    end
 
  end
end
