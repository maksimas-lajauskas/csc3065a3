import os
import subprocess
import sys
import datetime
from uuid import uuid1 as uuid
from string import Template

print("# args: "+ str(len(sys.argv)))
print("Args. received:")
print(str(sys.argv))


cfg = {
	#argsvars - common,
	"provider" : None,
	"arg_region" : None,
	"arg_num_crawlers" : None,
	"arg_max_num_crawlers" : None,
	"arg_num_ads_reg_pods" : None,
	"arg_max_num_ads_reg_pods" : None,
	"arg_num_search_pods" : None,
	"arg_max_num_search_pods" : None,
	"arg_build_containers" : None,
	"arg_deploy" : None,
	"arg_point_kubectl" : None,
	#argsvars - gcp
	"gcp_service_account_json" : None,
	"gcp_project_name" : None,
	#argsvars - aws
	"aws_access_key_id" : None,
	"aws_secret_access_key" : None,
	#argsvars - azure
	"azure_service_principal_id" : None,
	"azure_service_principal_secret" : None
}

def main():
	parse_args()
	if cfg["arg_build_containers"] is not None:
		if cfg["arg_build_containers"].casefold() == "true".casefold():
			build_containers()


#helper funcitons
def parse_args():
	for arg in sys.argv[2:]:
	arg_group = arg.split("=")
	if arg_group[0] in cfg:
		if arg_group[1].find(",") >= 0:
			cfg[arg_group[0]] = arg_group[1].split(",")
		else:
			cfg[arg_group[0]] = arg_group[1]
	else:
		print("These are possible args:")
		for key in cfg.keys():
			print(key)
		print("Args given as 'key=value' or 'key=value1,value2,value3'")
		sys.exit("Unrecognised argument: "+arg)		

def build_containers():
	subprocess.run(["docker","login"])
	ps = subprocess.run(["ps"."-e"], capture_output = True)
	#start dockerd
	if ps.stdout.decode().find("dockerd") == -1:
		sys.exit("Error: docker daemon not running. Start daemon and re-run script. Exiting...")
	#build_containers
	containers = ["crawler","ads","search"]
	outputs = []
	for module_name in containers:
		outputs.append(subprocess.run(["docker","build","-t",module_name, module_name], capture_output = True))
	#tag & push containers as :latest version




def define_tf_var(name, value):
	template = Template("variable $name {\n\tdefault = $value\n}\n")
	name = "\""+name+"\""
	if type(value) == type("string"):
		value = "\""+value+"\""
	return template.substitute(name=name,value=value)

def define_k8s_deployment(app_name, image, env_vars, target_replicas, max_replicas = None, port=80):
	if max_replicas is None:
		max_replicas = target_replicas + 1
	env_template = Template("""env {\n\t\t\t\t\t\tname = "$env_name"\n\t\t\t\t\t\tvalue = "$env_value"\n\t\t\t\t\t}\n""")
	env_block = ""
	for env_var_tuple in env_vars:
		env_block += env_template.substitute(env_name = env_var_tuple[0], env_value = env_var_tuple[1])
	deployment_template = Template("""
	resource "kubernetes_deployment" "$app_name" {
		metadata {
			name = "$app_name"
			labels = {
				App = "$app_name"
			}
		}
		spec {
			replicas = $target_replicas
			strategy {
				type = "RollingUpdate"
				rolling_update {
					max_surge = $max_replicas
					max_unavailable = $target_replicas
				}
			}
			selector {
				match_labels = {
					App = "$app_name"
				}
			}
			template {
				metadata{
					labels = {
						App = "$app_name"
					}
				}
				spec {
					container {
						image = "$image"
						name = "$app_name"
						resources {
									limits {
									 cpu	= "0.5"
									 memory = "256Mi"
									}
									requests {
									 cpu	= "250m"
									 memory = "50Mi"
									}
						}
						$env_block
						port {
							container_port = $port
						}
					}
				}
			}
		}
	}
	""")
	return deployment_template.substitute(app_name=app_name,image=image,target_replicas=target_replicas,max_replicas=max_replicas,env_block=env_block,port=port)


