module Virt
  class Host < Virt::Connection
    # Represents a Physical host which runs the libvirt daemon
    attr_accessor :libvirtcache, :guestcache
    attr_reader :connection
    
    def initialize
      @connection = Virt.connection.connection
      # The libvirt cache is used to store objects that were looked up previously so that we don't make multiple costly libvirt calls
      # The guestcache is used to store the guests that were created via the virt guest object
      # guestcache is used to cache virt guest obects
      @guestcache = {}
      # The libvirtcache is used to store the libvirt objects  
      @libvirtcache = {}
    end
    
    def name
      connection.hostname
    end
    
    def guests
      {:running => running_guests, :defined => defined_guests}
    end
    
    def version
      connection.version
    end
    
    def running_guests
      cleancache if libvirtcache.length > 0
      connection.list_domains.map do |domain|
        find_guest_by_id(domain)
      end
    end
    
    def defined_guests
      cleancache if libvirtcache.length > 0
      connection.list_defined_domains.map do |domain|
        find_guest_by_name domain
      end
    end
    def storage_pools
      connection.list_storage_pools.map {|p| create_pool({:name => p})}
    end
    
    # Returns a Virt::Pool object based on the pool name
    def storage_pool pool
      create_pool({:name => pool.is_a?(Libvirt::StoragePool) ? pool.name : pool })
    rescue Libvirt::RetrieveError
    end
    
    # Returns a hash of pools and their volumes objects.
    def volumes
      pools = {}
      storage_pools.each do |storage|
        pools[storage.name] = storage.volumes
      end
      pools
    end
    
    def find_guest_by_name name
      # check the guestcache first 
      if guestcache[name]
        return guestcache[name] 
      else
        if libvirtcache[name]
          domain = libvirtcache[name]
        else
          domain = connection.lookup_domain_by_name(name) 
          # cache the libvirt domain obj
          libvirtcache[domain.name] = domain
        end
        guest = create_guest({:name => name})
        # store in cache for future lookups
        guestcache[name] = guest
        return guest
      end
    end
    
    def find_guest_by_id id
      Array(id).map do |did|
        if libvirtcache[did]
          domain = libvirtcache[did]
        else
          domain = connection.lookup_domain_by_id(did)
          # cache the libvirt domain obj twice in order to have dual lookup methods
          libvirtcache[domain.name] = domain
          libvirtcache[did] = domain
        end
        # check the cache first 
        if guestcache[domain.name]
          guest = guestcache[domain.name]
	else
          guest = create_guest({:name => domain.name})
          # store in cache for future lookups
          guestcache[domain.name] = guest
	end
        return guest
      end
    end
    
    protected
    
    def cleancache
      # this will clean up the cache of any domains that may have been removed 
      newset = connection.list_domains.map + connection.list_defined_domains.map
      oldset = libvirtcache.keys.map
      removedset = oldset - newset
      # remove the entries in the cache
      removedset.each do | key |
	libvirtcache.delete(key)
        guestcache.delete(key)
      end
    end
    
    def create_guest opts
      guest = Virt::Guest.new opts
      guestcache[guest.name] = guest
      return guest
    end
    
    def create_pool opts
      Virt::Pool.new opts
    end
    
  end
end
