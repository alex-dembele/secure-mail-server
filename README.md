Secure Messaging Solution

**Overview**
A secure mail server setup using Docker, Postfix, Dovecot, MySQL, and a Flask-based REST API for user management. Includes automated backups to S3 and TLS/Let's Encrypt for security. Deployable with Docker Compose or Kubernetes.

**Prerequisites**
Docker and Docker Compose (for Docker deployment)
Kubernetes cluster with kubectl and Helm (for Kubernetes deployment)
AWS account with S3 bucket for backups
Domain name for mail server (e.g., example.com)
GitHub account for repository hosting

**Setup Instructions (Docker Compose)**
1- Clone the Repository
```
git clone https://github.com/alex-dembele/secure-mail-server
cd secure-mail-server
```

**Configure Environment Variables**
2- Create a .env file in the project root:MYSQL_ROOT_PASSWORD=rootpass
```
MYSQL_USER=mailuser
MYSQL_PASSWORD=mailpass
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_DEFAULT_REGION=your_aws_region
S3_BUCKET=your_s3_bucket
``


3- Update Domain in **docker-compose.yml** Replace **example.com** and **mail.example.com** with your actual domain.

4- Initialize DatabaseCopy init.sql to a volume or execute it in the MySQL container to set up the users table.

5- Run Docker Compose
```
docker-compose up -d
```

6- Obtain Let's Encrypt Certificates Initially run:
```
docker-compose exec certbot certonly --standalone -d mail.yourdomain.com
```


**Setup Instructions (Kubernetes)**
1- Clone the Repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo


Build and Push Docker ImagesBuild and push the API and backup images to a registry (e.g., Docker Hub):
docker build -t yourusername/mail-api:latest ./api
docker build -t yourusername/mail-backup:latest ./backup
docker push yourusername/mail-api:latest
docker push yourusername/mail-backup:latest


Create Namespace
kubectl create namespace mailserver


Configure SecretsUpdate kubernetes/manifests/secrets.yaml with base64-encoded values for your secrets:
echo -n 'your_aws_access_key' | base64

Apply the secrets:
kubectl apply -f kubernetes/manifests/secrets.yaml


Apply Manifests
kubectl apply -f kubernetes/manifests/


Using Helm (Alternative)

Update kubernetes/helm/values.yaml with your domain, AWS settings, etc.
Install the Helm chart:helm install secure-mail-server kubernetes/helm --namespace mailserver




Initialize DatabaseCreate a ConfigMap for init.sql:
kubectl create configmap db-init --from-file=init.sql -n mailserver


Obtain Let's Encrypt CertificatesRun a one-time job to get initial certificates:
kubectl run certbot-init --image=certbot/certbot --namespace=mailserver -- certonly --standalone -d mail.yourdomain.com



API Endpoints

POST /users: Create user (email, password)
GET /users/<email>: Retrieve user
PUT /users/<email>: Update user (password, active)
DELETE /users/<email>: Delete userExample:

curl -X POST http://<api-service-ip>:5000/users -d '{"email":"test@example.com","password":"pass123"}' -H "Content-Type: application/json"

Backup and Restore

Backup: Automated via Kubernetes CronJob, uploads to S3 daily at 2 AM.
Restore: Run the backup pod with the restore command:kubectl run backup-restore --image=yourusername/mail-backup:latest --namespace=mailserver -- python backup.py <s3_key>



Deployment

Push to GitHub:
git add .
git commit -m "Add Kubernetes support"
git push origin main


Set up CI/CD (optional) with GitHub Actions:

Create .github/workflows/ci.yml for automated builds and deployments.



Notes

Replace placeholders (e.g., your_aws_access_key, example.com) with actual values.
Monitor logs for issues:kubectl logs -n mailserver <pod-name>


Ensure ports 25, 587, and 993 are exposed via the LoadBalancer service for mailserver.
Use a cloud provider's storage class for PersistentVolumes.

Security Considerations

Use strong passwords and rotate AWS keys periodically.
Regularly update dependencies and images.
Monitor Let's Encrypt renewal logs in the certbot-logs PVC.
Restrict access to the API service with network policies if needed.

License
MIT License
