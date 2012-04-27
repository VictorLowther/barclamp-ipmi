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
#
# Note : This script runs on both the admin and compute nodes.
# It intentionally ignores the bios->enable node data flag.

include_recipe "utils"

return unless Chef::Recipe::IPMI.enable()

bmc_user     = node[:ipmi][:bmc_user]
bmc_password = node[:ipmi][:bmc_password]
bmc_address  = node["crowbar"]["network"]["bmc"]["address"]
bmc_netmask  = node["crowbar"]["network"]["bmc"]["netmask"]
bmc_router   = node["crowbar"]["network"]["bmc"]["router"]
bmc_use_vlan = node["crowbar"]["network"]["bmc"]["use_vlan"]
bmc_vlan     = if bmc_use_vlan
                 node["crowbar"]["network"]["bmc"]["vlan"].to_s
               else
                 "off"
               end
node["crowbar_wall"]["status"]["ipmi"]["user_set"] ||= false
node["crowbar_wall"]["status"]["ipmi"]["address_set"] ||= false
node.save

# lan parameters to check and set.
# The loop that follows iterates over this array.
# [0] = name in "print" output, [1] command fragment, [2] desired value,
# [3] = settle time
lan_params = [
              [ "IP Address Source" ,"static", "Static Address", 10 ] ,
              [ "IP Address" ,bmc_address, bmc_address, 1 ] ,
              [ "Subnet Mask" , bmc_netmask, bmc_netmask, 1 ] ,
              [ "Default VLAN", bmc_vlan, bmc_vlan, 10 ],
              [ "Interface Mode", "dedicated" ,"dedicated", 10 ]
             ]

unless bmc_router.nil? || bmc_router.empty?
  lan_params << [ "Default Gateway IP", bmc_router, bmc_router, 1 ]
end
lan_params.each do |param|
  ipmi_lan_set "#{param[0]}" do
    command param[1]
    value param[2]
    settle_time param[3]
    action :run
  end
end

unless node["crowbar_wall"]["status"]["ipmi"]["user_set"]
  ipmi_user_set "#{bmc_user}" do
    password bmc_password
    action :run
  end
end

ipmi_unload "ipmi_unload" do
  action :run
  only_if { node[:crowbar][:state] =~ /hardware/ }
end

end

