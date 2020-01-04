echo "resource \"kubernetes_deployment\" \"$crawlerID\" {" >> pods.tf
echo "    metadata {" >> pods.tf
echo "        name = \"$crawlerID\"" >> pods.tf
echo "        labels = {" >> pods.tf
echo "            App = \"$crawlerID\"" >> pods.tf
echo "        }" >> pods.tf
echo "    }" >> pods.tf
echo "    spec {" >> pods.tf
echo "        replicas = $num_crawlers" >> pods.tf
echo "        strategy {" >> pods.tf
echo "            type = \"RollingUpdate\"" >> pods.tf
echo "            rolling_update {" >> pods.tf
echo "                max_surge = $(( $num_crawlers + 1 ))" >> pods.tf
echo "                max_unavailable = $num_crawlers" >> pods.tf
echo "            }" >> pods.tf
echo "        }" >> pods.tf
echo "        selector {" >> pods.tf
echo "            match_labels = {" >> pods.tf
echo "                App = \"$crawlerID\"" >> pods.tf
echo "            }" >> pods.tf
echo "        }" >> pods.tf
echo "        template {" >> pods.tf
echo "            metadata{" >> pods.tf
echo "                labels = {" >> pods.tf
echo "                    App = \"$crawlerID\"" >> pods.tf
echo "                }" >> pods.tf
echo "            }" >> pods.tf
echo "            spec {" >> pods.tf
echo "                container {" >> pods.tf
echo "                    image = \"$crawler_gcr_tag@$crawler_sha\"" >> pods.tf
echo "                    name  = \"$crawlerID\"" >> pods.tf
echo "                    resources {" >> pods.tf
echo "                                limits {" >> pods.tf
echo "                                  cpu    = \"0.5\"" >> pods.tf
echo "                                  memory = \"256Mi\"" >> pods.tf
echo "                                }" >> pods.tf
echo "                                requests {" >> pods.tf
echo "                                  cpu    = \"250m\"" >> pods.tf
echo "                                  memory = \"50Mi\"" >> pods.tf
echo "                                }" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"QSEPROVIDER\"" >> pods.tf
echo "                          value = \"GCP\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"GCP_PROJECT_ID\"" >> pods.tf
echo "                          value = \"$gcp_proj_id\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"GOOGLE_APPLICATION_CREDENTIALS\"" >> pods.tf
echo "                          value = \"/keys.json\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"GCP_BIGTABLE_INSTANCE\"" >> pods.tf
echo "                          value = \"$gcp_bigtable_instance\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"GCP_BIGTABLE_INDEX_TABLE\"" >> pods.tf
echo "                          value = \"$gcp_bigtable_index_table\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"GCP_BIGTABLE_COLUMN_FAMILY\"" >> pods.tf
echo "                          value = \"$gcp_bigtable_column_family\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    env {" >> pods.tf
echo "                          name = \"COMMON_PAGE_CONTENT_COLUMN_NAME\"" >> pods.tf
echo "                          value = \"$common_page_content_column_name\"" >> pods.tf
echo "                    }" >> pods.tf
echo "                    port {" >> pods.tf
echo "                        container_port = 80" >> pods.tf
echo "                    }" >> pods.tf
echo "                }" >> pods.tf
echo "            }" >> pods.tf
echo "        }" >> pods.tf
echo "    }" >> pods.tf
echo "}" >> pods.tf
