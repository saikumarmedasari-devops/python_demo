output "ec2_public_ip" {
  description = "Public IP address of EC2"
  value       = aws_instance.python_app.public_ip
}

output "application_url" {
  description = "Python application URL"
  value       = "http://${aws_instance.python_app.public_ip}:5000"
}

output "ec2_instance_id" {
  value = aws_instance.python_app.id
}
