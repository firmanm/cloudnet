class CreateServerSupportActions < Struct.new(:user)
  
  def server_check(params, ip)
    @server_check ||= ServerWizard.new(default_params(params, ip).merge(params))
  end

  def default_params(params, ip)
    { location_id: Template.find(params[:template_id]).location.id, 
      name: auto_server_name,
      hostname: auto_server_name.parameterize,
      provisioner_role: nil,
      ip_addresses: 1,
      validation_reason: user.account.fraud_validation_reason(ip),
      user: user
    }
  end
  
  def auto_server_name
    "#{user.full_name} Server #{user.servers.count + 1}"
  end
  
  def build_api_errors
    return '' unless any_server_check_errors?
    build_api_error_message
  end
  
  def any_server_check_errors?
    @server_check.build_errors.any? || @server_check.errors.any?
  end
  
  def build_api_error_message
    error = {}
    error.merge! build: @server_check.build_errors if @server_check.build_errors.any?
    error.merge! @server_check.errors.messages.each_with_object({}) { |e, m| m[e[0]] = e[1] }
    { "error": error }
  end
end