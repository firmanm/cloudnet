class EditServerTask
  def initialize(user_id, server_id, old_disk_size, template_id, old_params)
    @user = User.find(user_id)
    @server = Server.find(server_id)
    @old_params = old_params
    @old_disk_size = old_disk_size
    @template_id = template_id
    @squall_vm   = Squall::VirtualMachine.new(*squall_params)
    @squall_disk = Squall::Disk.new(*squall_params)
  end
  
  def edit_server
    set_server_state(:building)
    tasks_order.each do |task|
      verifier = CoreTransactionVerifier.new(@user.id, @server.id)
      verifier.perform_transaction {send(task)}
    end
  ensure
    ServerTasks.new.perform(:refresh_server, @user.id, @server.id)
  end

  def tasks_order
    @tasks_order ||= begin
      order = []
      order << :change_params     if increasing_memory?
      order << :resize_disk       if increasing_disk_size?
      order << :rebuild_template  if template_changed?
      order << :resize_disk       if decreasing_disk_size?
      order << :change_params     if decreasing_memory?
      order
    end
  end
  
  private
  
    def change_params
      @squall_vm.edit(@server.identifier, params_options)
    end
  
    def resize_disk
      @squall_disk.edit(primary_disk_id, disk_options)
    end
  
    def rebuild_template
      @squall_vm.build(@server.identifier, template_options)
    end
  
    def set_server_state(state)
      @server.update_attribute(:state, state)
    end
  
    def increasing_disk_size?
      disk_size_changed? && @old_disk_size < @server.disk_size
    end
    
    def decreasing_disk_size?
      disk_size_changed? && @old_disk_size > @server.disk_size
    end
    
    def increasing_memory?
      params_changed? && @old_params["memory"] < @server.memory
    end
      
    def decreasing_memory?
      (params_changed? && @old_params["memory"] > @server.memory) ||
      (params_changed?  && !increasing_memory?)
    end
    
    def params_changed?
      @old_params != false
    end
    
    def disk_size_changed?
      @old_disk_size != false
    end
    
    def template_changed?
      @template_id != false
    end
  
    def primary_disk_id
      disks = @squall_disk.vm_disk_list(@server.identifier)
      disks.select{|d| d['primary'] == true}.first['id']
    end
    
    def disk_options
      {disk_size: @server.disk_size}
    end
    
    def template_options
      {
        template_id: Template.find(@template_id).identifier,
        required_startup: 1
      }
    end
    
    def params_options
      {
        label: @server.name,
        cpus: @server.cpus,
        memory: @server.memory
      }
    end
  
    def squall_params
      [uri: ONAPP_CP[:uri], user: @user.onapp_user, pass: @user.onapp_password]
    end
end