terraform {
  required_version = ">= 1.3"

  required_providers {
    splunk = {
      source = "splunk/splunk"
    }
  }
}

provider "splunk" {
  url                  = "localhost:8089"
  username             = "admin"
  password             = "splunkdev"
  insecure_skip_verify = true
}

resource "splunk_data_ui_views" "test" {
  name     = "example_dashboard"
  eai_data = chomp(file("${path.module}/dashboards/example_dashboard.xml"))
  acl {
    app     = "search"
    owner   = "admin"
    sharing = "app"
  }
}

resource "splunk_saved_searches" "test" {
  name   = "example_search"
  search = chomp(file("${path.module}/searches/example_search.spl"))
  acl {
    app     = "search"
    owner   = "admin"
    sharing = "app"
    read    = ["*"]
    write   = ["admin"]
  }
}
