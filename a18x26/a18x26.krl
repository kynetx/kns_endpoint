ruleset a18x26 {
  meta {
    name "Test Ruby Endpoint"
    description << Test Ruby Endpoint >>
    author "Michael Farmer"
    logging on
  }

  rule first_rule is active {
    select when test_endpoint echo
      pre {
        m = event:param("message");
      }
      {
        send_directive("say") with message = m;
      }
  }

  rule second_rule is active {
    select when test_endpoint echo_hello
      pre {
        m = event:param("message");
      }
      {
        send_directive("say") with message = m;
      }
  }

  rule third_rule is active {
    select when test_endpoint write_entity_var
      pre {
        m = event:param("message");
      }
      {
        noop();
      }
      fired {
        mark ent:message with m;
      }
      
  }
  

  rule fourth_rule is active {
    select when test_endpoint read_entity_var
      pre {
        m = current ent:message;
      }
      {
        send_directive("say") with message = m;  
      }
      
  }

}
