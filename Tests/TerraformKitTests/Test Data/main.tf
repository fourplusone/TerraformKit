terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "2.1.2"
    }
    local = {
      source = "hashicorp/local"
      version = "1.4.0"
    }
  }

}

resource "null_resource" "dummy-resource" {

}

resource "local_file" "foo" {
    content = "foo!"
    filename = "${path.module}/foo.bar"
}
