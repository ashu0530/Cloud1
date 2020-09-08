#Declare provider to tell terraform which cloud we need to contact

provider "aws" {
  profile = "ashu"     
  region  =   "ap-south-1"    
}

#create a security group/firewall rule to allow port ssh 22, http 80, https 443

resource "aws_default_vpc" "main" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_security_group" "project1_first_sg" {
  name        = "sg_for_webserver"
  description = "allow ssh and http, https traffic"
  vpc_id      =  aws_default_vpc.main.id

  ingress {
    description = "inbound_ssh_configuration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "all_traffic_outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description = "http_configuration"  
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  
}
  ingress {
  description = "https_configuration"  
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  }  

  tags = {
    Name = "project1_sg1"
  }
}

output "firewall_task1_sg1_info" {
  value = aws_security_group.project1_first_sg.name
}







# Create a key-pair for aws instance for login

#Generate a key using RSA algo
resource "tls_private_key" "instance_key1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#create a key-pair 
resource "aws_key_pair" "key_pair1" {
  key_name   = "project_key1"
  public_key = "${tls_private_key.instance_key1.public_key_openssh}"
  depends_on = [  tls_private_key.instance_key1 ]
}

#save the key file locally inside workspace in .pem extension file
resource "local_file" "save_project_key1" {
  content = "${tls_private_key.instance_key1.private_key_pem}"
  filename = "project_key1.pem"
  depends_on = [
   tls_private_key.instance_key1, aws_key_pair.key_pair1 ]
}



#Creating variable for aws ami instances
variable "ami_instance_id" {
	#AMI IMAGE NAME = Amazon Linux 2 AMI (HVM), SSD Volume Type
	default = "ami-0ebc1ac48dfd14136"
}

#Instance_creation 
resource "aws_instance" "project1_instance" {
  ami           = "${var.ami_instance_id}"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_pair1.key_name
  security_groups = [ "${aws_security_group.project1_first_sg.name}" ]
  availability_zone  = "ap-south-1a"


  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.instance_key1.private_key_pem
    host     = aws_instance.project1_instance.public_ip
  }
  
provisioner "remote-exec" {
    inline = [
      "sudo yum -y install httpd  php git",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "project1_webserver"
  }
}
output "instance1_az" {
  value = aws_instance.project1_instance.availability_zone
}
output "instance1_id" {
  value = aws_instance.project1_instance.id
}
output "public_ip_webserver" {
    value = aws_instance.project1_instance.public_ip
}




#Create EBS Volume for instance
resource "aws_ebs_volume" "ebs_vol1" {
	availability_zone  = "ap-south-1a"
	type	   = "gp2"
	size		   = 1
	tags		   = {
		Name = "project1_ebs1"
	}
  depends_on = [  
                  aws_instance.project1_instance,
  ]
}


output "ebs_vol1_info" {
  value = aws_ebs_volume.ebs_vol1.id
}

# To attach the Volume created 
resource "aws_volume_attachment" "ebs_vol1_attach" {  
 device_name = "/dev/sdh"  
 volume_id   = "${aws_ebs_volume.ebs_vol1.id}" 
 instance_id = "${aws_instance.project1_instance.id}" 
 force_detach = true
 
 depends_on = [   
  aws_instance.project1_instance,
  aws_ebs_volume.ebs_vol1,
   ]
 
 connection {
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.instance_key1.private_key_pem
    host     = aws_instance.project1_instance.public_ip
  }
# Volume partition, and format and mounting   
 provisioner "remote-exec" {  
     inline = [   
           
         "sudo mkfs.ext4  /dev/xvdh",  
         "sudo mount  /dev/xvdh  /var/www/html", 
         "sudo rm -rf /var/www/html/*",
         "sudo git clone https://github.com/ashu0530/webpage.git /var/www/html/"
              
               ] 
   }
}


#create snapshot of aws ebs volume
resource "aws_ebs_snapshot" "project1_snapshot" {
 volume_id  = "${aws_ebs_volume.ebs_vol1.id}"
 tags       = {
    Name = "project1_ebs_snap"
 }
 depends_on = [
    aws_volume_attachment.ebs_vol1_attach,
  ]
}  

output "task1_snapshot_id" {
	value = aws_ebs_snapshot.project1_snapshot.id
}


#Create a S3-bucket
resource "aws_s3_bucket" "project1_bucket" {
    bucket = "project1webserverbucket"
    acl    = "public-read"
    force_destroy = true 
    tags   = {
        Name = "project1-bucket"
        Environment = "Production"
   }
}
output "project1_bucket_id" {
    value = aws_s3_bucket.project1_bucket.id
}

#Applying bucket public access policy
resource "aws_s3_bucket_public_access_block" "project1_bucket_public_access_policy" {
    bucket = "${aws_s3_bucket.project1_bucket.id}"      
    block_public_acls = false
    block_public_policy = false 
    restrict_public_buckets = false
  }  


#Upload image to S3-Bucket

resource "aws_s3_bucket_object" "project1_object" {
    bucket = aws_s3_bucket.project1_bucket.bucket
    key    = "project1_image.jpg"
    acl    = "public-read"
    source = "C:/Users/Ashutosh/Desktop/pic1.jpg"
      depends_on = [
    aws_s3_bucket.project1_bucket,
  ]      
}

output "project1_bucket_domain_name" {
  value = aws_s3_bucket.project1_bucket.bucket_regional_domain_name
}




#Creating cloudfront
locals {
  s3_origin_id = aws_s3_bucket.project1_bucket.bucket
}

resource "aws_cloudfront_distribution" "project1_cloudfront" {
  origin {
      domain_name = "${aws_s3_bucket.project1_bucket.bucket_regional_domain_name}"
      origin_id   = "${local.s3_origin_id}"
      custom_origin_config {
          http_port = 80
          https_port = 443
          origin_protocol_policy = "match-viewer"
          origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
    }
  }
  enabled         = true
  is_ipv6_enabled = true  
  comment             = "building_cf"
  default_root_object = "index.php"

  default_cache_behavior {
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "${local.s3_origin_id}"
      forwarded_values {
          query_string = false
          cookies {
              forward = "none"
          }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 3600
      max_ttl                = 86400
}

  price_class = "PriceClass_All"

  restrictions {
      geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "project1_clouddfront"
    Environment = "production"
  }

  viewer_certificate {
      cloudfront_default_certificate = true
 
  }
  depends_on = [
      aws_s3_bucket_object.project1_object
  ]

} 

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.project1_cloudfront.domain_name
}




#locally saving the domain_name inside text file 
resource "null_resource" "cf_ip"  {
 provisioner "local-exec" {
     command = "echo  ${aws_cloudfront_distribution.project1_cloudfront.domain_name} > domain_name.txt"

   }
  depends_on = [   aws_cloudfront_distribution.project1_cloudfront, ]

}


#Updating in my website code 
resource "null_resource" "project1_add_image"  {
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = tls_private_key.instance_key1.private_key_pem
        host     = aws_instance.project1_instance.public_ip
  } 

    
    provisioner "remote-exec" {  
        inline = [ 
           
              "sudo sed -i '1i<img src='https://${aws_cloudfront_distribution.project1_cloudfront.domain_name}/project1_image.jpg' alt='ME' width='380' height='240' align='right'>' /var/www/html/index.php",
              "sudo sed -i '2i<p align='right'> <a href='https://www.linkedin.com/in/ashutosh-pandey-43b94b18b'>Visit To My LinkedIn Profile >>>> :) </a></p>' /var/www/html/index.php",

        ]                      
          
  } 
    depends_on = [    
aws_cloudfront_distribution.project1_cloudfront, 
 ]
 }


 
 
 #launching chrome browser for opening my website
 resource "null_resource" "ChromeOpen"  { 
     provisioner "local-exec" { 
           command = "start chrome ${aws_instance.project1_instance.public_ip}"  
     }
     depends_on = [ null_resource.project1_add_image,
     ]         
}