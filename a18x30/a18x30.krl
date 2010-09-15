ruleset a18x30 {
  meta {
    name "Testing Dev and Prod KNS Endpoint Gem"
    description <<
      Testing Dev and Prod KNS Endpoint Gem
    >>
    author "Michael Farmer"
    logging off
  }

  rule first_rule is active {
    select when test_endpoint echo
      {
        send_directive("say") with message = "DEVELOPMENT";
      }
  }
}
