data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.prefix}/base/vpc_id"subnet_id
}
data "aws_ssm_parameter" "subnet" {
  name = "/${var.prefix}/base/subnet/a/id"
}
data "aws_ssm_parameter" "ecr" {
  name = "/${var.prefix}/base/ecr"
}
data "aws_ssm_parameter" "subnetb" {
  name = "/${var.prefix}/base/subnet/b/id"
}


locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  subnet_id = data.aws_ssm_parameter.subnet.value
  ecr_url = data.aws_ssm_parameter.ecr.value
  subnetb_id=data.aws_ssm_parameter.subnetb.value
  /*serverconfig = [
    for srv in var.configuration : [
      for i in range(1, srv.no_of_instances+1) : {
        instance_name = "${srv.application_name}-${i}"
        //instance_type = srv.instance_type
       // subnet_id   = srv.subnet_id
        //ami = srv.ami
        security_groups = srv.vpc_security_group_ids
      }
    ]
  ]*/
}
// We need to Flatten it before using it
/*locals {
  instances = flatten(local.serverconfig)
}*/


resource "aws_security_group" "ssh_access" {
  vpc_id      = "${local.vpc_id}"
  name        = "${var.prefix}-ssh_access"
  description = "SSH access group"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP"
    createdBy = "infra-${var.prefix}/news"
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.prefix}-news"
  public_key = "${file("${path.module}/../id_rsa.pub")}"
}

data "aws_ami" "amazon_linux_2" {
 most_recent = true

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }

 filter {
   name = "architecture"
   values = ["x86_64"]
 }

 owners = ["137112412989"] #amazon
}

### Front end

resource "aws_security_group" "front_end_sg" {
  vpc_id      = "${local.vpc_id}"
  name        = "${var.prefix}-front_end"
  description = "Security group for front_end"

  tags = {
    Name = "SG for front_end"
    createdBy = "infra-${var.prefix}/news"
  }
}

# Allow all outbound connections
resource "aws_security_group_rule" "front_end_all_out" {
  type        = "egress"
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = "${aws_security_group.front_end_sg.id}"
}

resource "aws_instance" "front_end" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.ssh_key.key_name}"
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
    delete_on_termination = true
  }

  iam_instance_profile = "${var.prefix}-news_host"

  availability_zone = "${var.region}a"

  subnet_id = local.subnet_id

  vpc_security_group_ids = [
    "${aws_security_group.front_end_sg.id}",
    "${aws_security_group.ssh_access.id}"
  ]

  tags = {
    Name = "${var.prefix}-front_end"
    createdBy = "infra-${var.prefix}/news"
  }

  connection {
    host = "${self.public_ip}"
    type = "ssh"
    user = "ec2-user"
    private_key = "${file("${path.module}/../id_rsa")}"
  }

  provisioner "remote-exec" {
    script = "${path.module}/provision-docker.sh"
  }
  user_data=file("")
}

# Allow public access to the front-end server
resource "aws_security_group_rule" "front_end" {
  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]

  security_group_id = "${aws_security_group.front_end_sg.id}"
}
### end of front-end

resource "aws_security_group" "quotes_sg" {
  vpc_id      = "${local.vpc_id}"
  name        = "${var.prefix}-quotes_sg"
  description = "Security group for quotes"

  tags = {
    Name = "SG for quotes"
    createdBy = "infra-${var.prefix}/news"
  }
}

# Allow all outbound connections
resource "aws_security_group_rule" "quotes_all_out" {
  type        = "egress"
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = "${aws_security_group.quotes_sg.id}"
}

resource "aws_instance" "quotes" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.ssh_key.key_name}"
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
    delete_on_termination = true
  }

  iam_instance_profile = "${var.prefix}-news_host"

  availability_zone = "${var.region}a"

  subnet_id = local.subnet_id

  vpc_security_group_ids = [
    "${aws_security_group.quotes_sg.id}",
    "${aws_security_group.ssh_access.id}"
  ]

  tags = {
    Name = "${var.prefix}-quotes"
    createdBy = "infra-${var.prefix}/news"
  }

  connection {
    host = "${self.public_ip}"
    type = "ssh"
    user = "ec2-user"
    private_key = "${file("${path.module}/../id_rsa")}"
  }

  provisioner "remote-exec" {
    script = "${path.module}/provision-docker.sh"
  }
}

# Allow internal access to the quotes HTTP server from front-end
resource "aws_security_group_rule" "quotes_internal_http" {
  type        = "ingress"
  from_port   = 8082
  to_port     = 8082
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.front_end_sg.id}"
  security_group_id = "${aws_security_group.quotes_sg.id}"
}

resource "null_resource" "quotes_provision" {
  connection {
      host = "${aws_instance.quotes.public_ip}"
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("${path.module}/../id_rsa")}"
  }
  provisioner "file" {
    source = "${path.module}/provision-quotes.sh"
    destination = "/home/ec2-user/provision.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/provision.sh",
      "/home/ec2-user/provision.sh ${local.ecr_url}quotes:latest"
    ]
  }
}

resource "aws_security_group" "newsfeed_sg" {
  vpc_id      = "${local.vpc_id}"
  name        = "${var.prefix}-newsfeed_sg"
  description = "Security group for newsfeed"

  tags = {
    Name = "SG for newsfeed"
    createdBy = "infra-${var.prefix}/news"
  }
}

# Allow all outbound connections
resource "aws_security_group_rule" "newsfeed_all_out" {
  type        = "egress"
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = "${aws_security_group.newsfeed_sg.id}"
}

resource "aws_instance" "newsfeed" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.ssh_key.key_name}"
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
    delete_on_termination = true
  }

  iam_instance_profile = "${var.prefix}-news_host"

  availability_zone = "${var.region}a"

  subnet_id = local.subnet_id

  vpc_security_group_ids = [
    "${aws_security_group.newsfeed_sg.id}",
    "${aws_security_group.ssh_access.id}"
  ]

  tags = {
    Name = "${var.prefix}-newsfeed"
    createdBy = "infra-${var.prefix}/news"
  }

  connection {
    host = "${self.public_ip}"
    type = "ssh"
    user = "ec2-user"
    private_key = "${file("${path.module}/../id_rsa")}"
  }

  provisioner "remote-exec" {
    script = "${path.module}/provision-docker.sh"
  }
}

# Allow internal access to the newsfeed HTTP server from front-end
resource "aws_security_group_rule" "newsfeed_internal_http" {
  type        = "ingress"
  from_port   = 8081
  to_port     = 8081
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.front_end_sg.id}"
  security_group_id = "${aws_security_group.newsfeed_sg.id}"
}
/*resource "aws_instance" "newsapp" {
  
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.ssh_key.key_name}"
  associate_public_ip_address = true
  
  root_block_device {
    volume_type = "gp2"
    volume_size = 8
    delete_on_termination = true
  }

  iam_instance_profile = "${var.prefix}_news_host"

  availability_zone = "${var.region}a"

  subnet_id = local.subnet_id

  /*vpc_security_group_ids = [
    "${aws_security_group.front_end_sg.id}",
    "${aws_security_group.ssh_access.id}"
  ]*/
   for_each = {for server in local.instances: server.instance_name =>  server}
      vpc_security_group_ids = each.value.security_groups
       
   
   
  tags = {
    //Name = "${var.prefix}-${var.ec2-names[count.index]}"
    Name="${each.value.instance_name}"
    createdBy = "infra-${var.prefix}/news"
  }
   
  user_data=file("provision-docker.sh")
}*/
resource "null_resource" "newsfeed_provision" {
  connection {
      host = "${aws_instance.newsfeed.public_ip}"
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("${path.module}/../id_rsa")}"
  }
  provisioner "file" {
    source = "${path.module}/provision-newsfeed.sh"
    destination = "/home/ec2-user/provision.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/provision.sh",
      "/home/ec2-user/provision.sh ${local.ecr_url}newsfeed:latest"
    ]
  }
}

resource "null_resource" "front_end_provision" {
  connection {
      host = "${aws_instance.front_end.public_ip}"
      type = "ssh"
      user = "ec2-user"
      private_key = "${file("${path.module}/../id_rsa")}"
  }
  provisioner "file" {
    source = "${path.module}/provision-front_end.sh"
    destination = "/home/ec2-user/provision.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/provision.sh",
<<EOF
      /home/ec2-user/provision.sh \
      --region ${var.region} \
      --docker-image ${local.ecr_url}front_end:latest \
      --quote-service-url http://${aws_instance.quotes.private_ip}:8082 \
      --newsfeed-service-url http://${aws_instance.newsfeed.private_ip}:8081 \
      --static-url http://${aws_s3_bucket.news.website_endpoint}
EOF
    ]
  }
}

output "frontend_url" {
  value = "http://${aws_instance.front_end.public_ip}:8080"
}

resource "aws_elb" "bar" {
  name               = "foobar-terraform-elb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  access_logs {
    bucket        = "foo"
    bucket_prefix = "bar"
    interval      = 60
  }
  
  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 8000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = [aws_instance.foo.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "foobar-terraform-elb"
  }
}

resource "aws_autoscaling_group" "bar" {
  name                      = "front-end-asg"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  //placement_group           = aws_placement_group.test.id
  launch_configuration      = aws_launch_configuration.asg_launch_config.name
   vpc_zone_identifier       = [locals.subnet_id, locals.subnetb_id]

  initial_lifecycle_hook {
    name                 = "foobar"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"

    notification_metadata = jsonencode({
      foo = "bar"
    })

    notification_target_arn = "arn:aws:sqs:us-east-1:444455556666:queue1*"
    role_arn                = "arn:aws:iam::123456789012:role/S3Access"
  }

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "lorem"
    value               = "ipsum"
    propagate_at_launch = false
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "asg_launch_config" {
  name_prefix   = "terraform-lc-example-"
  image_id      = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_type}"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "foobar" {
  availability_zones        = ["us-west-2a"]
  name                      = "terraform-test-foobar5"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  termination_policies      = ["OldestInstance"]
}