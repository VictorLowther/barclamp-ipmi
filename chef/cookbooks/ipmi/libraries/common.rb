#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This contains common routines for the IPMI recipes
class Chef::Recipe::IPMI
  private
  # Map of value -> ipmitool commands to set that value.
  # We put them here so they are all in the same place, and
  # are therefore easier to debug.
  @@get_set_map={
    "Set In Progress" => "",
    "IP Address Source" => "ipmitool lan #{node[:ipmi][:lan_channel]} ipsrc",
    "IP Address" => "ipmitool lan #{node[:ipmi][:lan_channel]} ipaddr",
    "Subnet Mask" => "ipmitool lan #{node[:ipmi][:lan_channel]} netmask",
    "MAC Address" => "ipmitool lan #{node[:ipmi][:lan_channel]} macaddr",
    "Default Gateway IP" => "ipmitool lan #{node[:ipmi][:lan_channel]} defgw ipaddr",
    "Default Gateway MAC" => "ipmitool lan #{node[:ipmi][:lan_channel]} defgw macaddr",
    "Backup Gateway IP" => "ipmitool lan #{node[:ipmi][:lan_channel]} bakgw ipaddr",
    "Backup Gateway MAC" => "ipmitool lan #{node[:ipmi][:lan_channel]} bakgw macaddr",
    "802.1q VLAN ID" => "ipmitool lan #{node[:ipmi][:lan_channel]} vlan id",
    "802.1q VLAN Priority" => "ipmitool lan #{node[:ipmi][:lan_channel]} vlan priority"
    "Interface Mode" => "ipmitool delloem lan set"
  }
  # The current config of IPMI things we care about.
  # This is essentially a cache that is populated when we get a value
  # and it is cleared when we set a value.
  @@current_config = nil
  # A list of platforms that are flat-out unsupported.  We will not even try
  # to load on these devices.
  @@unsupported = [ "kvm",
                    "bochs",
                    "vmware virtual platform",
                    "virtualbox" ]

  public
  def self.message(msg)
    node[:crowbar_wall] ||= Mash.new
    node[:crowbar_wall][:status] ||= Mash.new
    node[:crowbar_wall][:status][:ipmi] ||= Mash.new
    node[:crowbar_wall][:status][:ipmi][:messages] ||= Array.new
    node[:crowbar_wall][:status][:ipmi][:messages] << msg
    node.save
  end

  # Try to enable the BMC on this system.  We return true if we were able
  # to enable IPMI, false otherwise.
  def self.enable
    # If we are false or true, then enable has already run. Do not run it again.
    return node[:ipmi][:bmc_enable] unless node[:ipmi][:bmc_enable].nil?
    # Find out if we can enable the BMC.  Default to assuming we cannot.
    node[:ipmi][:bmc_enable] = false
    node.save
    if @@unsupported.member?(node[:dmi][:system][:product_name].downcase)
      self.message "Unsupported product node[:dmi][:system][:product_name], not enabling IPMI"
      return false
    end
    # If we cannot load required modules, we are done.
    %w{ipmi_si ipmi_devintf}.each do |m|
      next unless File.exists "/sys/module/#{m}"
      unless Kernel.system("modprobe #{m}")
        self.message "Unable to load module #{m}, cannot enable IPMI"
        self.disable
        return false
      end
    end
    unless ::Kernel.system("which ipmitool")
      p = package "ipmitool" do
        case node[:platform]
        when "ubuntu","debian"
          package_name "ipmitool"
        when "redhat","centos"
          package_name "OpenIPMI-tools"
        end
        action :nothing
      end
      p.run_action(:install)
    end
    [0..4].each do |c|
      next unless Kernel.system("ipmitool channel info #{c} |grep -q '802.3 LAN'")
      node[:ipmi][:lan_channel] = c
      node[:ipmi][:bmc_enable] = true
      node.save
      return true
    end
    self.message "Cannot find LAN channel for BMC, not enabling IPMI"
    self.disable
    return false
  end

  def self.disable
    %w(ipmi_si ipmi_devintf ipmi_msghandler).each do |m|
      next unless File.exists? "/sys/module/#{m}"
      Kernel.system("rmmod #{m}")
    end
    @@current_config = nil
    node[:ipmi][:bmc_enable] = nil unless node[:ipmi][:bmc_enable] == false
    node[:ipmi][:lan_channel] = nil
    self.message "IPMI support disabled."
    node.save
  end

  def self.[](key)
    raise RangeError.new("#{key.to_s} is not a valid IPMI LAN setting") unless @@get_set_map[key]
    unless @@current_config
      IO.popen("ipmitool lan print #{node[:ipmi][:lan_channel]}") do |line|
        p = line.split(':',2)
        k = p[0].strip
        v = p[1].strip
        next if k.empty?
        @@current_config[k]=v
      end
      @@current_config["Interface Mode"]=%x{ipmitool delloem lan get}.strip
    end
    @@current_config[key]
  end

  def self.[]=(key,val)
    raise RangeError.new("#{key.to_s} is not a valid IPMI LAN setting") unless @@get_set_map[key]
    raise RangeError.new("IPMI LAN value #{key.to_s} is read-only") if @@get_set_map[key].empty?
    unless val = @@current_config[key]
      @@current_config = nil
      return false unless Kernel.system("#{@@get_set_map[key]} #{val}")
    end
    val
  end
end
