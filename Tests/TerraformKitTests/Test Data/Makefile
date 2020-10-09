all: data.swift

.terraform/plugins/selections.json: main.tf
	terraform init

demo.plan: main.tf .terraform/plugins/selections.json
	terraform plan -out demo.plan
	
empty.plan: empty/main.tf .terraform/plugins/selections.json
	terraform plan -out empty.plan empty
	
output.plan: output/main.tf .terraform/plugins/selections.json
	terraform plan -out output.plan output

data.swift: demo.plan empty.plan output.plan
	echo let demoPlan = "#\"\"\"\\n`terraform show -json demo.plan`\\n\"\"\"#.data(using:.utf8)!" > data.swift
	echo let emptyPlan = "#\"\"\"\\n`terraform show -json empty.plan`\\n\"\"\"#.data(using:.utf8)!" >> data.swift
	echo let outputPlan = "#\"\"\"\\n`terraform show -json output.plan`\\n\"\"\"#.data(using:.utf8)!" >> data.swift
