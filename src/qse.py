import os
import subprocess
import sys
import datetime
import shutil
import traceback
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
	"create_cluster" : None,
	"full_run" : None,
	"build_containers" : None,
	"write_tf_defs": None,
	"force_write_pod_defs": None,
	"deploy" : None,
	"point_kubectl" : None,
	"skip_docker_build" : None,
	#argsvars - gcp
	"gcp_service_account_json" : None,
	"gcp_project_id" : None,
	#argsvars - aws
	"aws_access_key_id" : None,
	"aws_secret_access_key" : None,
	#argsvars - azure
	"azure_service_tenant_id" : None,
	"azure_service_principal_id" : None,
	"azure_service_principal_secret" : None
}

#constants
qse_storage_bucket_name = "qse-storage-bucket-40073762-csc3065-assignment-3"
docker_repo  = "mlajauskas01/docker-hub:"
k8s_cluster_name  = "qse-eks-cluster"
azure_kubesync_cmd = "export KUBECONFIG="+os.environ["HOME"]+"/.kube_config"

def main():
	try:
		#configure
		parse_args()
		print("Obtained configuration...")
		for c in str(cfg).replace("{","").replace("}","").split(", "):
			print(c)
		#run
		if chk_argl(["build_containers","full_run"]) and not chk_arg("skip_docker_build"):
			build_containers() #1
		if chk_argl(["write_tf_defs","full_run","create_cluster"]):
			write_tf_defs(chk_arg("force_write_pod_defs")) #2
		if chk_argl(["deploy","create_cluster","full_run"]):
			deploy() #3
		if chk_argl(["point_kubectl","full_run"]):
			point_kubectl() #4
		if chk_argl(["deploy","create_cluster","full_run"]):
			write_tf_defs(True) #5
		if chk_argl(["deploy","create_cluster","full_run"]):
			deploy() #6
		print("Done")
		if chk_arg("provider","azure"):
			print("Run the following command after 'full_run=true' or 'deploy=true + point_kubectl=true' finish successfully to use kubectl on azure:\n"+azure_kubesync_cmd)
		sys.exit(0)
	except:
		if str(sys.exc_info()[1]) != str(SystemExit(0)):
			err = sys.exc_info()
			traceback.print_tb(err[2])
			sys.exit("ERROR: "+str(err))


#component funcitons
def chk_argl(argl, lval=["true"]):
	for arg in argl:
		for val in lval:
			if chk_arg(arg, val):
				return True
	return False

def chk_arg(arg, val="true"):
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
	login = subprocess.run(["sudo","docker","login"]).returncode
	if login != 0:
		sys.exit("Bad login, exiting...")
	ps = subprocess.run(["ps","-e"],capture_output=True)
	print("check - dockerd running..?")
	if int(ps.stdout.decode().find("dockerd")) < 0:
		sys.exit("Error: docker daemon not running. Start daemon and re-run script. Exiting...")
	#build_containers
	print("building images (may take a few minutes)...")
	outputs = []
	for module_name in ["crawler","ads","search"]:
		for provider in ["aws","gcp","azure"]:
			filename = provider+"_storage_interface.py"
			shutil.copyfile(src=filename,dst=module_name+"/"+filename)
		outputs.append(subprocess.run(["sudo","docker","build","-t",module_name, module_name],capture_output=True))
	#tag & push containers as :latest version
	print("pushing images (may take some time depending on upload speed)...")
	for module_name in ["crawler","ads","search"]:
		outputs.append(subprocess.run(["sudo","docker","tag", module_name+":latest", docker_repo+module_name],capture_output=True))
		outputs.append(subprocess.run(["sudo","docker","push", docker_repo+module_name],capture_output=True))
	for output in outputs:
		if output.returncode != 0:
			for o in outputs:
				print(str(o.args)+" --> Exit code: "+str(o.returncode))
			sys.exit("There was an error building one or more containers. Check Dockerfiles for errors and re-run or build manually. Exiting...")

def point_kubectl():
	if chk_argl(["provider"],["gcp","aws","azure"]):
		os.chdir("tf-"+cfg["provider"])
		if chk_arg("provider","gcp"):
			cluster_name = cfg["gcp_project_id"]+"-cluster"
			region = cfg["region"]
			gcp_project_id = cfg["gcp_project_id"]
			cmdlist = ["gcloud", "container", "clusters", "get-credentials", cluster_name, "--region", region, "--project", gcp_project_id]
			cmd = subprocess.run(cmdlist,capture_output=True)
			if cmd.returncode != 0:
				print(str(cmd.args)+" --> Exit code: "+str(cmd.returncode))
				sys.exit("Couldn't point kubectl to k8s cluster, exiting...")
		if chk_arg("provider","aws"):
			outputs = []
			outputs.append(subprocess.run(["terraform","output","kubeconfig"],capture_output=True))
			outputs.append(subprocess.run(["terraform","output","config_map_aws_auth"],capture_output=True))
			homekube = os.environ["HOME"]+"/.kube/config"
			shutil.copyfile(src=homekube,dst=homekube+"_backup_"+uuid().hex)
			k_cfg = open(homekube,"w+")
			k_cfg.write(outputs[0].stdout.decode())
			k_cfg.close()
			outputs.append(subprocess.run(["aws","eks","update-kubeconfig","--name",k8s_cluster_name],capture_output=True))
			cmaa = open("config_map_aws_auth.yaml","w+")
			cmaa.write(outputs[1].stdout.decode())
			cmaa.close()
			outputs.append(subprocess.run(["kubectl","apply","-f","config_map_aws_auth.yaml"],capture_output=True))
			for o in outputs:
				if o.returncode != 0:##awsclipontktcl
					for o2 in outputs:
						print(str(o2.args)+" --> Exit code: "+str(o2.returncode))
					sys.exit("Error pointing kubectl to k8s cluster, exiting...")
		if chk_arg("provider","azure"):
			outputs = []
			outputs.append(subprocess.run(["terraform","output","kube_config"],capture_output=True))
			homekube = os.environ["HOME"]+"/.kube_config"
			k_cfg = open(homekube,"w+")
			k_cfg.write(outputs[0].stdout.decode())
			k_cfg.close()
			for o in outputs:
				if o.returncode != 0:
					for o2 in outputs:
						print(str(o2.args)+" --> Exit code: "+str(o2.returncode))
					sys.exit("Error pointing kubectl to k8s cluster, exiting...")
		os.chdir("..")

def deploy():
	if chk_argl(["provider"],["gcp","aws","azure"]):
		os.chdir("tf-"+cfg["provider"])
		subprocess.run(["terraform","init"])
		subprocess.run(["terraform","apply","-auto-approve"])
		os.chdir("..")

def write_tf_defs(can_write_pod_defs=False):
	if chk_argl(["provider"],["gcp","aws","azure"]):
		pod_env_vars = []
		varstring = ""
		os.chdir("tf-"+cfg["provider"])
		varstring += define_tf_var("cluster-name",k8s_cluster_name)
		varstring += define_tf_var("region",cfg["region"])
		varstring += define_tf_var("qse_storage_bucket_name",qse_storage_bucket_name)
		if chk_arg("provider","gcp"):
			#deploymentvars.tf for running terraform
			if chk_arg("provider","gcp"):
				ogpath = os.path.abspath(cfg["gcp_service_account_json"])
				newpath = cfg["gcp_service_account_json"].split("/")[-1:][0]
				print("OLDPATH: " + str(ogpath))
				print("NEWPATH: " + newpath)
				shutil.copyfile(src=ogpath,dst=newpath)
				cfg["gcp_service_account_json"] = newpath
			varstring += define_tf_var("gcp_proj_id",cfg["gcp_project_id"])
			varstring += define_tf_var("gcp_key_json",os.path.abspath(cfg["gcp_service_account_json"]))
			if can_write_pod_defs:
				creds = open(os.path.abspath(cfg["gcp_service_account_json"]),"r")
				pod_env_vars.append(("GOOGLE_APPLICATION_CREDENTIALS",str(urlsafe_b64encode(creds.read().encode()))))#gcp creds
				pod_env_vars.append(("QSE_STORAGE_BUCKET_NAME",qse_storage_bucket_name))#storage bucket name
				creds.close()
		elif chk_arg("provider","aws"):
			import requests
			varstring += define_tf_var("deploying_machine_public_ip",requests.get("https://ipv4.icanhazip.com/").text[:-2])
			if can_write_pod_defs:
				pod_env_vars.append(("aws_access_key_id",cfg["aws_access_key_id"]))
				pod_env_vars.append(("aws_secret_access_key",cfg["aws_secret_access_key"]))
				pod_env_vars.append(("QSE_STORAGE_BUCKET_NAME","aws_s3_bucket.qse_s3_bucket.id"))#storage bucket name
		elif chk_arg("provider","azure"):
			varstring += define_tf_var("qse-azure-service-principal-id",cfg["azure_service_principal_id"])
			varstring += define_tf_var("qse-azure-service-principal-secret",cfg["azure_service_principal_secret"])
			if can_write_pod_defs:
				pod_env_vars.append(("azure_storage_account_name","azurerm_storage_account.qse.name"))
				pod_env_vars.append(("AZURE_TENANT_ID",cfg["azure_service_tenant_id"]))
				pod_env_vars.append(("AZURE_CLIENT_ID",cfg["azure_service_principal_id"]))
				pod_env_vars.append(("AZURE_CLIENT_SECRET",cfg["azure_service_principal_secret"]))
				pod_env_vars.append(("QSE_STORAGE_BUCKET_NAME",qse_storage_bucket_name))#storage bucket name
	else:
		sys.exit("Uknown provider")
	#deployment vars write
	deploymentvars_tf = open("deploymentvars.tf", "w+")
	deploymentvars_tf.write(varstring)
	deploymentvars_tf.close()
	#pods.tf
	if can_write_pod_defs:
		pod_env_vars.append(("QSEPROVIDER",cfg["provider"].upper()))#provider
		pods_tf = open("pods.tf", "w+")
		services_tf = open("services.tf","w+")
			#write defs
		for pod in ["crawler","search","ads"]:
			pods_tf.write(
				define_k8s_deployment(
						app_name=pod,
						image=docker_repo+pod+get_sha_affix(pod),
						env_vars=pod_env_vars,
						target_replicas=cfg["num_"+pod+"_pods"],
						max_replicas = cfg["max_num_"+pod+"_pods"]
					)
				)
			services_tf.write(
					define_k8s_load_balancer(app_name=pod)
				)
		pods_tf.close()
		services_tf.close()
	os.chdir("..")#return to src dir

def get_sha_affix(pod):
	pull = subprocess.run(["sudo","docker","pull",docker_repo+pod],capture_output=True)
	raw = subprocess.run(["sudo","docker","images","--digests"],capture_output=True)
	lines = raw.stdout.decode().split("\n")
	good_lines = []
	for line in lines:
		words = line.split(" ")
		good_words = []
		if len(words) == 0:
			continue
		for word in words:
			if len(word) > 0 and word != " ":
				good_words.append(word)
		good_lines.append(good_words)	
	for line in good_lines:
		if line[0] == docker_repo[:-1] and line[1] == pod:
			return "@"+line[2]
	return ""


def define_tf_var(name, value):
	template = Template("variable $name {\n\tdefault = $value\n}\n")
	name = "\""+name+"\""
	if type(value) == type("string") and value[:1] != "\"" and value[-1:] != "\"":
		value = "\""+value+"\""
	return template.substitute(name=name,value=value)

def define_k8s_load_balancer(app_name):
	template = Template("""
resource "kubernetes_service" "$app_name-service" {
  metadata {
    name = "$app_name-service"
  }
  spec {
    selector = {
      App = kubernetes_deployment.$app_name.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

output "lb-$app_name" {
value = kubernetes_service.$app_name-service.load_balancer_ingress[0]
}
""")
	return template.substitute(app_name=app_name)

def define_k8s_deployment(app_name, image, env_vars = [], target_replicas = None, max_replicas = None, port=80):
	if target_replicas is None:
		target_replicas = 1
	if max_replicas is None:
		max_replicas = target_replicas + 1
	i = 0
	for pair in env_vars:
		if pair[1].find(".") < 0 and type(pair[1]) == type("string") and pair[1][:1] != "\"" and pair[1][-1:] != "\"":
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

