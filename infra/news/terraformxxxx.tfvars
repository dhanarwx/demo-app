configuration = [
  {
    "application_name" : "front-end",
      "no_of_instances" : "1",
     //"subnet_id" : "subnet-0f4f294d8404946eb",
  
    "vpc_security_group_ids" : ["sg-0608043b9548c5f67","sg-0f5fde21b7a839718"]
  },
  {
    "application_name" : "quotes",
      
   
    "no_of_instances" : "1"
    
    "vpc_security_group_ids" : ["sg-0608043b9548c5f67","sg-0a56e1e627140d070"]
  },
  {
    "application_name" : "newsfeed",
  
    
    "no_of_instances" : "1"
    
    "vpc_security_group_ids" : ["sg-0608043b9548c5f67","sg-0330fc212d0289ee6"]
  }
  
]