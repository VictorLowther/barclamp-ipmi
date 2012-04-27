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
Chef::Recipe::IPMI.message "Performing initial discovery of IPMI"

node["crowbar_wall"]["ipmi"]["address"] = Chef::Recipe::IPMI["IP Address"]
node["crowbar_wall"]["ipmi"]["gateway"] = Chef::Recipe::IPMI["Default Gateway IP"]
node["crowbar_wall"]["ipmi"]["netmask"] = Chef::Recipe::IPMI["Subnet Mask"]
node["crowbar_wall"]["ipmi"]["mode"] = Chef::Recipe::IPMI["Interface Mode"]
node.save

Chef::Recipe::IPMI.disable()

