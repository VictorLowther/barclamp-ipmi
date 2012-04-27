# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

action :run do
  name = new_resource.name
  settle_time = new_resource.settle_time

  ruby_block "Load IPMI" do
    block do
      return true if node[:ipmi][:bmc_enable]
      if Chef::Recipe::IPMI.enable()
        Chef::Recipe::IPMI.message "IPMI enabled. Settling for #{settle_time}"
        sleep settle_time.to_i
      else
        Chef::Recipe::IPMI.message "Could not enable IPMI"
      end
    end
  end
end

