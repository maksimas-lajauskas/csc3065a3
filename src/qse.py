import os
import subprocess
import sys
import datetime
import shutil
from uuid import uuid1 as uuid
from string import Template
from base64 import urlsafe_b64encode

print("# args: "+ str(len(sys.argv)))
print("Args. received:")
print(str(sys.argv))


cfg = {
	#argsvars - common
	"provider" : None,
	"region" : None,
	"num_crawler_pods" : None,
	"max_num_crawler_pods" : None,
	"num_ads_pods" : None,
	"max_num_ads_pods" : None,
	"num_search_pods" : None,
	"max_num_search_pods" : None,
	#script actions
	"full_run" : None,
	"build_containers" : None,
	"write_tf_defs": None,
	"deploy" : None,
	"point_kubectl" : None,
	#argsvars - gcp
	"gcp_service_account_json" : None,
	"gcp_project_id" : None,
	#argsvars - aws
	"aws_access_key_id" : None,
	"aws_secret_access_key" : None,
	#argsvars - azure
	"azure_service_principal_id" : None,
	"azure_service_principal_secret" : None
}

qse_storage_bucket_name = "40073762_QSE_STORAGE_BUCKET_CSC3065_ASSIGNMENT_3"
docker_repo  = "mlajauskas01/docker-hub:"
def main():
	try:
		#configure
		parse_args()
		print("Obtained configuration...")
		for c in str(cfg).replace("{","").replace("}","").split(", "):
			print(c)
		#run
		if chk_arg("build_containers","true") or chk_arg("full_run","true"):
			build_containers()
		if chk_arg("write_tf_defs","true") or chk_arg("full_run","true"):
			write_tf_defs() #todo
		if chk_arg("deploy","true") or chk_arg("full_run","true"):
			deploy() #todo
		if chk_arg("point_kubectl","true") or chk_arg("full_run","true"):
			point_kubectl() #todo
		print("Done")
		ok = True
		sys.exit(0)
	except:
		if str(sys.exc_info()[1]) != str(SystemExit(0)):
			sys.exit("ERROR: "+str(sys.exc_info()))


#component funcitons
def chk_argl(arg, lval):
	for val in lval:
		if chk_arg(arg, val):
			return True
	return False

def chk_arg(arg, val):
	try:
		if cfg[arg] is not None:
			if cfg[arg].casefold() == val.casefold():
				return True
		return False
	except:
		return False

def parse_args():
	if len(sys.argv) > 1:
		for arg in sys.argv[1:]:
			arg_group = arg.split("=")
			if arg_group[0] in cfg:
				if arg_group[1].find(",") >= 0:
					cfg[arg_group[0]] = arg_group[1].split(",")
				else:
					cfg[arg_group[0]] = arg_group[1]
			else:
				help_text()
				sys.exit("Unrecognised argument: "+arg)		
	else:
		help_text()
		sys.exit(0)		

def help_text():
	print("These are possible args:")
	for key in cfg.keys():
		print(key)
	print("Args given as 'key=value'") #" or 'key=value1,value2,value3'")

def build_containers():
	print("start container build...")
	login = subprocess.run(["docker","login"]).returncode
	if login != 0:
		sys.exit("Bad login, exiting...")
	ps = subprocess.run(["ps","-e"], capture_output = True)
	print("check - dockerd running..?")
	if ps.stdout.decode().find("dockerd") != 0:
		sys.exit("Error: docker daemon not running. Start daemon and re-run script. Exiting...")
	#build_containers
	print("building images (may take a few minutes)...")
	outputs = []
	for module_name in ["crawler","ads","search"]:
		for provider in ["aws","gcp","azure"]:
			filename = provider+"_storage_interface.py"
			shutil.copyfile(src=filename,dst=module_name+"/"+filename)
		outputs.append(subprocess.run(["docker","build","-t",module_name, module_name], capture_output = True))
	#tag & push containers as :latest version
	print("building images (may take some time depending on upload speed)...")
	for module_name in containers:
		outputs.append(subprocess.run(["docker","tag", module_name+":latest", docker_repo+module_name], capture_output = True))
		outputs.append(subprocess.run(["docker","push", docker_repo+module_name], capture_output = True))
	for output in outputs:
		if output.returncode != 0:
			for o in outputs:
				print(str(o.args)+" --> Exit code: "+o.returncode)
			sys.exit("There was an error building one or more containers. Check Dockerfiles for errors and re-run or build manually. Exiting...")

def write_tf_defs():
	if chk_argl("provider",["gcp","aws","azure"]):
		os.chdir("tf-"+cfg["provider"])
		if chk_arg("provider","gcp"):
			#deploymentvars.tf for running terraform
			varstring = ""
			varstring += define_tf_var("gcp_proj_id",cfg["gcp_project_id"])
			varstring += define_tf_var("region",cfg["region"])
			varstring += define_tf_var("gcp_key_json",os.path.abspath(cfg["gcp_service_account_json"]))
			varstring += define_tf_var("qse_storage_bucket_name",qse_storage_bucket_name)
			deploymentvars_tf = open("deploymentvars.tf", "w+")
			deploymentvars_tf.write(varstring)
			deploymentvars_tf.close()
			#pods.tf
			pods_tf = open("pods.tf", "w+")
				#gcp creds
			creds = open(os.path.abspath(cfg["gcp_service_account_json"]),"r")
			pod_env_vars = [("GOOGLE_APPLICATION_CREDENTIALS",str(urlsafe_b64encode(creds.read().encode())))]
			creds.close()
				#pod config
			pod_env_vars.append(("QSE_STORAGE_BUCKET_NAME",qse_storage_bucket_name))
			pod_env_vars.append(("QSEPROVIDER",cfg["provider"].upper()))
				#write defs
			for pod in ["crawler","search","ads"]:
				pods_tf.write(
					define_k8s_deployment(
							app_name=pod,
							image=docker_repo+pod,
							env_vars=pod_env_vars,
							target_replicas=cfg["num_"+pod+"_pods"],
							max_replicas = cfg["max_num_"+pod+"_pods"]
						)
					)
			pods_tf.close()
		elif chk_arg("provider","aws"):
			print("AINT DONE YET")
		elif chk_arg("provider","azure"):
			print("AINT DONE YET")
	else:
		sys.exit("Uknown provider")

def define_tf_var(name, value):
	template = Template("variable $name {\n\tdefault = $value\n}\n")
	name = "\""+name+"\""
	if type(value) == type("string"):
		value = "\""+value+"\""
	return template.substitute(name=name,value=value)

def define_k8s_deployment(app_name, image, env_vars = [], target_replicas = None, max_replicas = None, port=80):
	if target_replicas is None:
		target_replicas = 1
	if max_replicas is None:
		max_replicas = target_replicas + 1
	i = 0
	for pair in env_vars:
		if pair[1].find(".") < 0 and type(pair[1]) == type("string"):
			env_vars[i] = (pair[0],"\""+pair[1]+"\"")
		i += 1
	env_template = Template("""\n\t\t\t\t\tenv {\n\t\t\t\t\t\tname = "$env_name"\n\t\t\t\t\t\tvalue = $env_value\n\t\t\t\t\t}\n""")
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

#run hook
if __name__ == "__main__":
	main()

