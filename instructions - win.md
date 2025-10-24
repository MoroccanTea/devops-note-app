# Exercice Pratique d'Infrastructure AWS Complète (Sans Terraform)

## Vue d'ensemble de l'exercice

Cet exercice pratique vous permettra de mettre en œuvre une infrastructure complète sur AWS en utilisant **la Console AWS, AWS CLI et des scripts** (vous pouvez l'améliorer avec Terraform). Vous allez déployer une application web complète avec base de données, monitoring, sécurité et automatisation.

---

## Architecture Cible

Application web de gestion de tâches (To-Do App) avec:

- **Frontend:** Application web statique hébergée sur S3 + CloudFront
- **Backend:** API REST sur EC2
- **Base de données:** RDS PostgreSQL (Free Tier)
- **Load Balancer:** Application Load Balancer
- **Stockage:** S3 pour les fichiers statiques
- **Monitoring:** CloudWatch
- **Sécurité:** IAM, Security Groups, Secrets Manager
- **Réseau:** VPC personnalisé avec subnets publics et privés

---

## Prérequis

- Compte AWS (Free Tier)
- AWS CLI installé et configuré
- Git installé
- PowerShell ou Command Prompt sur Windows

---

## Partie 1: Configuration Initiale du Compte AWS (30 min)

### Étape 1.1: Sécurisation du compte root

**Via Console AWS:**

1. **Activer MFA sur le compte root**
   - Connexion avec le compte root
   - Aller dans: **Mon compte de sécurité** (icône utilisateur en haut à droite)
   - Cliquer sur **Authentification multifacteur (MFA)**
   - Cliquer sur **Activer MFA**
   - Choisir **Application d'authentification**
   - Scanner le QR code avec Google Authenticator ou Authy
   - Entrer deux codes MFA consécutifs

2. **Créer un utilisateur IAM administrateur**
   - Aller dans: **Services > IAM**
   - Cliquer sur **Utilisateurs** > **Créer un utilisateur**
   - Nom: `devops-admin`
   - Cocher: **Accès à AWS Management Console**
   - Type de mot de passe: **Mot de passe personnalisé**
   - Décocher: **L'utilisateur doit créer un nouveau mot de passe...**
   - Cliquer sur **Suivant**
   - Sélectionner: **Attacher directement les stratégies existantes**
   - Rechercher et cocher: **AdministratorAccess**
   - Cliquer sur **Suivant** puis **Créer un utilisateur**
   - **IMPORTANT:** Noter l'URL de connexion console

3. **Créer des clés d'accès pour AWS CLI**
   - Dans IAM, cliquer sur l'utilisateur `devops-admin`
   - Onglet **Informations d'identification de sécurité**
   - Cliquer sur **Créer une clé d'accès**
   - Sélectionner: **Interface de ligne de commande (CLI)**
   - Cocher: **Je comprends la recommandation ci-dessus...**
   - Cliquer sur **Suivant** puis **Créer une clé d'accès**
   - **IMPORTANT:** Télécharger le fichier CSV avec les clés

4. **Configurer AWS CLI (Windows PowerShell)**
```powershell
# Configurer le profil AWS CLI
aws configure --profile devops-admin
# AWS Access Key ID: [votre clé]
# AWS Secret Access Key: [votre secret]
# Default region name: eu-north-1
# Default output format: json

# Définir ce profil par défaut
$env:AWS_PROFILE = "devops-admin"
[Environment]::SetEnvironmentVariable("AWS_PROFILE", "devops-admin", "User")
```

### Étape 1.2: Configuration des Alertes Budgétaires

**Via Console AWS:**

1. Aller dans: **Services > Billing > Budgets**
2. Cliquer sur **Créer un budget**
3. Sélectionner: **Personnaliser (avancé)**
4. Type de budget: **Budget de coût**
5. Nom: `devops-training-budget`
6. Période: **Mensuel**
7. Type de budget: **Fixe**
8. Montant budgété: **10 USD**
9. Cliquer sur **Suivant**
10. Seuil d'alerte: **80%** du montant budgété
11. Adresse e-mail: [votre e-mail]
12. Cliquer sur **Suivant** puis **Créer un budget**

---

## Partie 2: Infrastructure Réseau (VPC) (45 min)

### Étape 2.1: Créer le VPC

**Via Console AWS:**

1. **Créer le VPC**
   - Services > **VPC**
   - Cliquer sur **Créer un VPC**
   - Sélectionner: **VPC uniquement**
   - Nom: `devops-vpc`
   - Bloc CIDR IPv4: `10.0.0.0/16`
   - Cocher: **Activer les noms d'hôte DNS**
   - Cocher: **Activer la résolution DNS**
   - Tags: `Name=devops-vpc`, `Environment=training`, `Project=devops-infrastructure`
   - Cliquer sur **Créer un VPC**

**Via AWS CLI (PowerShell):**

```powershell
# Créer le VPC
$VPC_ID = aws ec2 create-vpc `
  --cidr-block 10.0.0.0/16 `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=devops-vpc},{Key=Environment,Value=training}]' `
  --query 'Vpc.VpcId' `
  --output text

Write-Host "VPC ID: $VPC_ID"

# Activer DNS hostnames
aws ec2 modify-vpc-attribute `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --enable-dns-hostnames

# Activer DNS support
aws ec2 modify-vpc-attribute `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --enable-dns-support
```

### Étape 2.2: Créer les Subnets

**Via AWS CLI (PowerShell):**

```powershell
# Subnet Public 1 (AZ a)
$PUBLIC_SUBNET_1 = aws ec2 create-subnet `
  --vpc-id $VPC_ID `
  --cidr-block 10.0.1.0/24 `
  --availability-zone eu-north-1a `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-public-subnet-1},{Key=Type,Value=Public}]' `
  --query 'Subnet.SubnetId' `
  --output text

Write-Host "Public Subnet 1: $PUBLIC_SUBNET_1"

# Activer l'attribution automatique d'IP publique
aws ec2 modify-subnet-attribute `
  --subnet-id $PUBLIC_SUBNET_1 `
  --region eu-north-1 `
  --map-public-ip-on-launch

# Subnet Public 2 (AZ b)
$PUBLIC_SUBNET_2 = aws ec2 create-subnet `
  --vpc-id $VPC_ID `
  --cidr-block 10.0.2.0/24 `
  --availability-zone eu-north-1b `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-public-subnet-2},{Key=Type,Value=Public}]' `
  --query 'Subnet.SubnetId' `
  --output text

Write-Host "Public Subnet 2: $PUBLIC_SUBNET_2"

aws ec2 modify-subnet-attribute `
  --subnet-id $PUBLIC_SUBNET_2 `
  --region eu-north-1 `
  --map-public-ip-on-launch

# Subnet Privé 1 (AZ a)
$PRIVATE_SUBNET_1 = aws ec2 create-subnet `
  --vpc-id $VPC_ID `
  --cidr-block 10.0.11.0/24 `
  --availability-zone eu-north-1a `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-private-subnet-1},{Key=Type,Value=Private}]' `
  --query 'Subnet.SubnetId' `
  --output text

Write-Host "Private Subnet 1: $PRIVATE_SUBNET_1"

# Subnet Privé 2 (AZ b)
$PRIVATE_SUBNET_2 = aws ec2 create-subnet `
  --vpc-id $VPC_ID `
  --cidr-block 10.0.12.0/24 `
  --availability-zone eu-north-1b `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-private-subnet-2},{Key=Type,Value=Private}]' `
  --query 'Subnet.SubnetId' `
  --output text

Write-Host "Private Subnet 2: $PRIVATE_SUBNET_2"
```

### Étape 2.3: Créer et Configurer l'Internet Gateway

```powershell
# Créer Internet Gateway
$IGW_ID = aws ec2 create-internet-gateway `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=devops-igw}]' `
  --query 'InternetGateway.InternetGatewayId' `
  --output text

Write-Host "Internet Gateway ID: $IGW_ID"

# Attacher l'IGW au VPC
aws ec2 attach-internet-gateway `
  --internet-gateway-id $IGW_ID `
  --vpc-id $VPC_ID `
  --region eu-north-1
```

### Étape 2.4: Créer le NAT Gateway

```powershell
# Allouer une Elastic IP pour le NAT Gateway
$EIP_ALLOC_ID = aws ec2 allocate-address `
  --domain vpc `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=devops-nat-eip}]' `
  --query 'AllocationId' `
  --output text

Write-Host "Elastic IP Allocation ID: $EIP_ALLOC_ID"

# Créer le NAT Gateway dans le subnet public 1
$NAT_GW_ID = aws ec2 create-nat-gateway `
  --subnet-id $PUBLIC_SUBNET_1 `
  --allocation-id $EIP_ALLOC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=devops-nat-gateway}]' `
  --query 'NatGateway.NatGatewayId' `
  --output text

Write-Host "NAT Gateway ID: $NAT_GW_ID"

# Attendre que le NAT Gateway soit disponible (environ 2-3 minutes)
Write-Host "Attente de la disponibilité du NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region eu-north-1
Write-Host "NAT Gateway disponible!"
```

### Étape 2.5: Créer les Tables de Routage

```powershell
# Table de routage publique
$PUBLIC_RT_ID = aws ec2 create-route-table `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=devops-public-rt}]' `
  --query 'RouteTable.RouteTableId' `
  --output text

Write-Host "Public Route Table ID: $PUBLIC_RT_ID"

# Ajouter une route vers Internet via l'IGW
aws ec2 create-route `
  --route-table-id $PUBLIC_RT_ID `
  --destination-cidr-block 0.0.0.0/0 `
  --gateway-id $IGW_ID `
  --region eu-north-1

# Associer les subnets publics à la table de routage publique
aws ec2 associate-route-table `
  --route-table-id $PUBLIC_RT_ID `
  --subnet-id $PUBLIC_SUBNET_1 `
  --region eu-north-1

aws ec2 associate-route-table `
  --route-table-id $PUBLIC_RT_ID `
  --subnet-id $PUBLIC_SUBNET_2 `
  --region eu-north-1

# Table de routage privée
$PRIVATE_RT_ID = aws ec2 create-route-table `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=devops-private-rt}]' `
  --query 'RouteTable.RouteTableId' `
  --output text

Write-Host "Private Route Table ID: $PRIVATE_RT_ID"

# Ajouter une route vers Internet via le NAT Gateway
aws ec2 create-route `
  --route-table-id $PRIVATE_RT_ID `
  --destination-cidr-block 0.0.0.0/0 `
  --nat-gateway-id $NAT_GW_ID `
  --region eu-north-1

# Associer les subnets privés à la table de routage privée
aws ec2 associate-route-table `
  --route-table-id $PRIVATE_RT_ID `
  --subnet-id $PRIVATE_SUBNET_1 `
  --region eu-north-1

aws ec2 associate-route-table `
  --route-table-id $PRIVATE_RT_ID `
  --subnet-id $PRIVATE_SUBNET_2 `
  --region eu-north-1
```

### Étape 2.6: Sauvegarder les IDs (PowerShell)

```powershell
# Créer un fichier pour sauvegarder les IDs
$configPath = "$env:USERPROFILE\devops-aws-config.ps1"

@"
`$VPC_ID = '$VPC_ID'
`$PUBLIC_SUBNET_1 = '$PUBLIC_SUBNET_1'
`$PUBLIC_SUBNET_2 = '$PUBLIC_SUBNET_2'
`$PRIVATE_SUBNET_1 = '$PRIVATE_SUBNET_1'
`$PRIVATE_SUBNET_2 = '$PRIVATE_SUBNET_2'
`$IGW_ID = '$IGW_ID'
`$NAT_GW_ID = '$NAT_GW_ID'
`$PUBLIC_RT_ID = '$PUBLIC_RT_ID'
`$PRIVATE_RT_ID = '$PRIVATE_RT_ID'
"@ | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "Configuration sauvegardée dans: $configPath"
```

---

## Partie 3: Security Groups (30 min)

### Étape 3.1: Créer les Security Groups

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Security Group pour ALB (Application Load Balancer)
$ALB_SG_ID = aws ec2 create-security-group `
  --group-name devops-alb-sg `
  --description "Security group for Application Load Balancer" `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-alb-sg}]' `
  --query 'GroupId' `
  --output text

Write-Host "ALB Security Group ID: $ALB_SG_ID"

# Autoriser le trafic HTTP (port 80) depuis Internet
aws ec2 authorize-security-group-ingress `
  --group-id $ALB_SG_ID `
  --protocol tcp `
  --port 80 `
  --cidr 0.0.0.0/0 `
  --region eu-north-1

# Autoriser le trafic HTTPS (port 443) depuis Internet
aws ec2 authorize-security-group-ingress `
  --group-id $ALB_SG_ID `
  --protocol tcp `
  --port 443 `
  --cidr 0.0.0.0/0 `
  --region eu-north-1

# Security Group pour EC2 (Backend)
$EC2_SG_ID = aws ec2 create-security-group `
  --group-name devops-ec2-sg `
  --description "Security group for EC2 instances" `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-ec2-sg}]' `
  --query 'GroupId' `
  --output text

Write-Host "EC2 Security Group ID: $EC2_SG_ID"

# Autoriser le trafic depuis l'ALB (port 8000 pour l'API)
aws ec2 authorize-security-group-ingress `
  --group-id $EC2_SG_ID `
  --protocol tcp `
  --port 8000 `
  --source-group $ALB_SG_ID `
  --region eu-north-1

# Autoriser SSH depuis votre IP (remplacez par votre IP)
# Pour obtenir votre IP: Invoke-RestMethod -Uri "https://api.ipify.org"
$MY_IP = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
aws ec2 authorize-security-group-ingress `
  --group-id $EC2_SG_ID `
  --protocol tcp `
  --port 22 `
  --cidr "$MY_IP/32" `
  --region eu-north-1

Write-Host "Accès SSH autorisé depuis: $MY_IP"

# Security Group pour RDS
$RDS_SG_ID = aws ec2 create-security-group `
  --group-name devops-rds-sg `
  --description "Security group for RDS database" `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-rds-sg}]' `
  --query 'GroupId' `
  --output text

Write-Host "RDS Security Group ID: $RDS_SG_ID"

# Autoriser PostgreSQL (port 5432) depuis EC2
aws ec2 authorize-security-group-ingress `
  --group-id $RDS_SG_ID `
  --protocol tcp `
  --port 5432 `
  --source-group $EC2_SG_ID `
  --region eu-north-1

# Sauvegarder les Security Group IDs
@"
`$ALB_SG_ID = '$ALB_SG_ID'
`$EC2_SG_ID = '$EC2_SG_ID'
`$RDS_SG_ID = '$RDS_SG_ID'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8

Write-Host "Security Groups créés et configurés!"
```

---

## Partie 4: Base de Données RDS (30 min)

### Étape 4.1: Créer un DB Subnet Group

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer le DB Subnet Group
aws rds create-db-subnet-group `
  --db-subnet-group-name devops-db-subnet-group `
  --db-subnet-group-description "Subnet group for DevOps RDS instance" `
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 `
  --region eu-north-1 `
  --tags "Key=Name,Value=devops-db-subnet-group"

Write-Host "DB Subnet Group créé!"
```

### Étape 4.2: Créer l'instance RDS PostgreSQL

```powershell
# Générer un mot de passe aléatoire sécurisé
$DB_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})

Write-Host "Mot de passe DB généré (à sauvegarder): $DB_PASSWORD"

# Créer l'instance RDS
$DB_INSTANCE = aws rds create-db-instance `
  --db-instance-identifier devops-postgres-db `
  --db-instance-class db.t3.micro `
  --engine postgres `
  --engine-version 15.4 `
  --master-username dbadmin `
  --master-user-password $DB_PASSWORD `
  --allocated-storage 20 `
  --storage-type gp2 `
  --vpc-security-group-ids $RDS_SG_ID `
  --db-subnet-group-name devops-db-subnet-group `
  --backup-retention-period 7 `
  --no-publicly-accessible `
  --region eu-north-1 `
  --tags "Key=Name,Value=devops-postgres-db" "Key=Environment,Value=training" `
  --query 'DBInstance.DBInstanceIdentifier' `
  --output text

Write-Host "Instance RDS créée: $DB_INSTANCE"
Write-Host "Attente de la disponibilité de l'instance (environ 5-10 minutes)..."

# Attendre que l'instance soit disponible
aws rds wait db-instance-available `
  --db-instance-identifier devops-postgres-db `
  --region eu-north-1

Write-Host "Instance RDS disponible!"

# Récupérer l'endpoint de la base de données
$DB_ENDPOINT = aws rds describe-db-instances `
  --db-instance-identifier devops-postgres-db `
  --region eu-north-1 `
  --query 'DBInstances[0].Endpoint.Address' `
  --output text

Write-Host "DB Endpoint: $DB_ENDPOINT"

# Sauvegarder les informations de la DB
@"
`$DB_ENDPOINT = '$DB_ENDPOINT'
`$DB_PASSWORD = '$DB_PASSWORD'
`$DB_USERNAME = 'dbadmin'
`$DB_NAME = 'devopsdb'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

### Étape 4.3: Stocker le mot de passe dans AWS Secrets Manager

```powershell
# Créer un secret pour le mot de passe de la base de données
$SECRET_STRING = @{
    username = "dbadmin"
    password = $DB_PASSWORD
    engine = "postgres"
    host = $DB_ENDPOINT
    port = 5432
    dbname = "devopsdb"
} | ConvertTo-Json

$SECRET_ARN = aws secretsmanager create-secret `
  --name devops/db/credentials `
  --description "Database credentials for DevOps infrastructure" `
  --secret-string $SECRET_STRING `
  --region eu-north-1 `
  --tags "Key=Name,Value=devops-db-credentials" `
  --query 'ARN' `
  --output text

Write-Host "Secret créé dans Secrets Manager: $SECRET_ARN"

# Sauvegarder l'ARN du secret
@"
`$SECRET_ARN = '$SECRET_ARN'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

---

## Partie 5: Stockage S3 (20 min)

### Étape 5.1: Créer les buckets S3

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Générer un identifiant unique pour les buckets
$BUCKET_SUFFIX = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})

# Bucket pour le frontend
$FRONTEND_BUCKET = "devops-frontend-$BUCKET_SUFFIX"
aws s3api create-bucket `
  --bucket $FRONTEND_BUCKET `
  --region eu-north-1 `
  --create-bucket-configuration LocationConstraint=eu-north-1

Write-Host "Bucket frontend créé: $FRONTEND_BUCKET"

# Activer l'hébergement web statique
aws s3 website "s3://$FRONTEND_BUCKET/" `
  --index-document index.html `
  --error-document error.html

# Bucket pour les logs
$LOGS_BUCKET = "devops-logs-$BUCKET_SUFFIX"
aws s3api create-bucket `
  --bucket $LOGS_BUCKET `
  --region eu-north-1 `
  --create-bucket-configuration LocationConstraint=eu-north-1

Write-Host "Bucket logs créé: $LOGS_BUCKET"

# Activer le versioning sur le bucket frontend
aws s3api put-bucket-versioning `
  --bucket $FRONTEND_BUCKET `
  --versioning-configuration Status=Enabled `
  --region eu-north-1

# Sauvegarder les noms des buckets
@"
`$FRONTEND_BUCKET = '$FRONTEND_BUCKET'
`$LOGS_BUCKET = '$LOGS_BUCKET'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

### Étape 5.2: Configurer la politique du bucket frontend

```powershell
# Créer la politique du bucket
$BUCKET_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$FRONTEND_BUCKET/*"
    }
  ]
}
"@

# Sauvegarder temporairement la politique
$BUCKET_POLICY | Out-File -FilePath "$env:TEMP\bucket-policy.json" -Encoding UTF8

# Appliquer la politique
aws s3api put-bucket-policy `
  --bucket $FRONTEND_BUCKET `
  --policy "file://$env:TEMP\bucket-policy.json" `
  --region eu-north-1

Write-Host "Politique du bucket appliquée"

# Désactiver le blocage de l'accès public pour permettre la politique
aws s3api put-public-access-block `
  --bucket $FRONTEND_BUCKET `
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" `
  --region eu-north-1

Write-Host "Accès public configuré"
```

---

## Partie 6: EC2 et Application Load Balancer (60 min)

### Étape 6.1: Créer une paire de clés SSH

```powershell
# Créer le répertoire .ssh si nécessaire
$sshDir = "$env:USERPROFILE\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

# Créer la paire de clés
aws ec2 create-key-pair `
  --key-name devops-keypair `
  --region eu-north-1 `
  --query 'KeyMaterial' `
  --output text | Out-File -FilePath "$sshDir\devops-keypair.pem" -Encoding ASCII

Write-Host "Paire de clés créée: $sshDir\devops-keypair.pem"

# Sur Windows, vous devrez peut-être ajuster les permissions du fichier
# Si vous utilisez OpenSSH sur Windows, exécutez dans PowerShell en tant qu'administrateur:
# icacls "$sshDir\devops-keypair.pem" /inheritance:r
# icacls "$sshDir\devops-keypair.pem" /grant:r "$env:USERNAME:(R)"
```

### Étape 6.2: Créer l'Application Load Balancer

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer l'ALB
$ALB_ARN = aws elbv2 create-load-balancer `
  --name devops-alb `
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 `
  --security-groups $ALB_SG_ID `
  --region eu-north-1 `
  --tags "Key=Name,Value=devops-alb" `
  --query 'LoadBalancers[0].LoadBalancerArn' `
  --output text

Write-Host "ALB créé: $ALB_ARN"

# Récupérer le DNS de l'ALB
$ALB_DNS = aws elbv2 describe-load-balancers `
  --load-balancer-arns $ALB_ARN `
  --region eu-north-1 `
  --query 'LoadBalancers[0].DNSName' `
  --output text

Write-Host "ALB DNS: $ALB_DNS"

# Créer le Target Group
$TG_ARN = aws elbv2 create-target-group `
  --name devops-tg `
  --protocol HTTP `
  --port 8000 `
  --vpc-id $VPC_ID `
  --region eu-north-1 `
  --health-check-path "/api/health" `
  --health-check-interval-seconds 30 `
  --health-check-timeout-seconds 5 `
  --healthy-threshold-count 2 `
  --unhealthy-threshold-count 3 `
  --tags "Key=Name,Value=devops-tg" `
  --query 'TargetGroups[0].TargetGroupArn' `
  --output text

Write-Host "Target Group créé: $TG_ARN"

# Créer le Listener pour l'ALB
$LISTENER_ARN = aws elbv2 create-listener `
  --load-balancer-arn $ALB_ARN `
  --protocol HTTP `
  --port 80 `
  --region eu-north-1 `
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN" `
  --query 'Listeners[0].ListenerArn' `
  --output text

Write-Host "Listener créé: $LISTENER_ARN"

# Sauvegarder les informations de l'ALB
@"
`$ALB_ARN = '$ALB_ARN'
`$ALB_DNS = '$ALB_DNS'
`$TG_ARN = '$TG_ARN'
`$LISTENER_ARN = '$LISTENER_ARN'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

### Étape 6.3: Créer un rôle IAM pour EC2

```powershell
# Créer la politique de confiance pour EC2
$TRUST_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

$TRUST_POLICY | Out-File -FilePath "$env:TEMP\trust-policy.json" -Encoding UTF8

# Créer le rôle IAM
$ROLE_NAME = "devops-ec2-role"
aws iam create-role `
  --role-name $ROLE_NAME `
  --assume-role-policy-document "file://$env:TEMP\trust-policy.json" `
  --description "IAM role for DevOps EC2 instances"

Write-Host "Rôle IAM créé: $ROLE_NAME"

# Attacher les politiques nécessaires
aws iam attach-role-policy `
  --role-name $ROLE_NAME `
  --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

aws iam attach-role-policy `
  --role-name $ROLE_NAME `
  --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

# Créer une politique personnalisée pour Secrets Manager
$SECRETS_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "$SECRET_ARN"
    }
  ]
}
"@

$SECRETS_POLICY | Out-File -FilePath "$env:TEMP\secrets-policy.json" -Encoding UTF8

aws iam put-role-policy `
  --role-name $ROLE_NAME `
  --policy-name SecretsManagerAccess `
  --policy-document "file://$env:TEMP\secrets-policy.json"

# Créer le profil d'instance
aws iam create-instance-profile --instance-profile-name devops-ec2-profile

# Ajouter le rôle au profil
aws iam add-role-to-instance-profile `
  --instance-profile-name devops-ec2-profile `
  --role-name $ROLE_NAME

Write-Host "Profil d'instance créé et configuré"

# Attendre un peu pour que le profil soit propagé
Start-Sleep -Seconds 10
```

### Étape 6.4: Créer le script User Data

```powershell
# Créer le script de démarrage
$USER_DATA = @"
#!/bin/bash
set -e

# Mettre à jour le système
dnf update -y

# Installer Docker
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Installer Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Installer Git
dnf install -y git

# Installer AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Installer CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Créer le répertoire de l'application
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Récupérer les credentials de la base de données depuis Secrets Manager
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id devops/db/credentials --region eu-north-1 --query SecretString --output text)
export DB_HOST=$(echo `$DB_SECRET | jq -r '.host')
export DB_USER=$(echo `$DB_SECRET | jq -r '.username')
export DB_PASSWORD=$(echo `$DB_SECRET | jq -r '.password')
export DB_NAME=$(echo `$DB_SECRET | jq -r '.dbname')

# Créer le fichier .env
cat > /home/ec2-user/app/.env << EOF
DATABASE_URL=postgresql://`${DB_USER}:`${DB_PASSWORD}@`${DB_HOST}:5432/`${DB_NAME}
NODE_ENV=production
PORT=8000
EOF

# Le code de l'application sera déployé séparément
echo "Instance initialisée avec succès!"
"@

$USER_DATA | Out-File -FilePath "$env:TEMP\user-data.sh" -Encoding UTF8

Write-Host "Script User Data créé"
```

### Étape 6.5: Lancer l'instance EC2

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Trouver l'AMI Amazon Linux 2023 la plus récente
$AMI_ID = aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" `
  --region eu-north-1 `
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' `
  --output text

Write-Host "AMI sélectionnée: $AMI_ID"

# Lancer l'instance EC2
$INSTANCE_ID = aws ec2 run-instances `
  --image-id $AMI_ID `
  --instance-type t3.micro `
  --key-name devops-keypair `
  --security-group-ids $EC2_SG_ID `
  --subnet-id $PUBLIC_SUBNET_1 `
  --iam-instance-profile Name=devops-ec2-profile `
  --user-data "file://$env:TEMP\user-data.sh" `
  --region eu-north-1 `
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-backend},{Key=Environment,Value=training}]' `
  --query 'Instances[0].InstanceId' `
  --output text

Write-Host "Instance EC2 lancée: $INSTANCE_ID"
Write-Host "Attente du démarrage de l'instance..."

# Attendre que l'instance soit en cours d'exécution
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region eu-north-1

Write-Host "Instance en cours d'exécution!"

# Récupérer l'IP publique
$INSTANCE_PUBLIC_IP = aws ec2 describe-instances `
  --instance-ids $INSTANCE_ID `
  --region eu-north-1 `
  --query 'Reservations[0].Instances[0].PublicIpAddress' `
  --output text

Write-Host "IP publique de l'instance: $INSTANCE_PUBLIC_IP"

# Enregistrer l'instance dans le Target Group
aws elbv2 register-targets `
  --target-group-arn $TG_ARN `
  --targets "Id=$INSTANCE_ID" `
  --region eu-north-1

Write-Host "Instance enregistrée dans le Target Group"

# Sauvegarder les informations de l'instance
@"
`$INSTANCE_ID = '$INSTANCE_ID'
`$INSTANCE_PUBLIC_IP = '$INSTANCE_PUBLIC_IP'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8

Write-Host "✓ Infrastructure EC2 et ALB créée avec succès!"
Write-Host "Attendez environ 5 minutes pour que l'instance termine son initialisation"
```

---

## Partie 7: CloudFront Distribution (30 min)

### Étape 7.1: Créer une Origin Access Identity

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer l'OAI
$OAI_CONFIG = @"
{
  "CallerReference": "devops-oai-$(Get-Date -Format 'yyyyMMddHHmmss')",
  "Comment": "OAI for DevOps frontend bucket"
}
"@

$OAI_CONFIG | Out-File -FilePath "$env:TEMP\oai-config.json" -Encoding UTF8

$OAI_ID = aws cloudfront create-cloud-front-origin-access-identity `
  --cloud-front-origin-access-identity-config "file://$env:TEMP\oai-config.json" `
  --query 'CloudFrontOriginAccessIdentity.Id' `
  --output text

Write-Host "Origin Access Identity créée: $OAI_ID"

# Sauvegarder l'OAI ID
@"
`$OAI_ID = '$OAI_ID'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

### Étape 7.2: Mettre à jour la politique du bucket S3

```powershell
# Récupérer le Canonical User ID de l'OAI
$OAI_CANONICAL_USER = aws cloudfront describe-cloud-front-origin-access-identity `
  --id $OAI_ID `
  --query 'CloudFrontOriginAccessIdentity.S3CanonicalUserId' `
  --output text

# Nouvelle politique du bucket avec OAI
$NEW_BUCKET_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFrontAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $OAI_ID"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$FRONTEND_BUCKET/*"
    }
  ]
}
"@

$NEW_BUCKET_POLICY | Out-File -FilePath "$env:TEMP\new-bucket-policy.json" -Encoding UTF8

aws s3api put-bucket-policy `
  --bucket $FRONTEND_BUCKET `
  --policy "file://$env:TEMP\new-bucket-policy.json" `
  --region eu-north-1

Write-Host "Politique du bucket mise à jour pour CloudFront"
```

### Étape 7.3: Créer la distribution CloudFront

```powershell
# Configuration de la distribution CloudFront
$CF_CONFIG = @"
{
  "CallerReference": "devops-cf-$(Get-Date -Format 'yyyyMMddHHmmss')",
  "Comment": "CloudFront distribution for DevOps frontend",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$FRONTEND_BUCKET",
        "DomainName": "$FRONTEND_BUCKET.s3.eu-north-1.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": "origin-access-identity/cloudfront/$OAI_ID"
        }
      }
    ]
  },
  "DefaultRootObject": "index.html",
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$FRONTEND_BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "PriceClass": "PriceClass_100",
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true,
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  }
}
"@

$CF_CONFIG | Out-File -FilePath "$env:TEMP\cf-config.json" -Encoding UTF8

$CF_DISTRIBUTION_ID = aws cloudfront create-distribution `
  --distribution-config "file://$env:TEMP\cf-config.json" `
  --query 'Distribution.Id' `
  --output text

Write-Host "Distribution CloudFront créée: $CF_DISTRIBUTION_ID"
Write-Host "Attente du déploiement (peut prendre 15-20 minutes)..."

# Récupérer le domain name de la distribution
$CF_DOMAIN = aws cloudfront get-distribution `
  --id $CF_DISTRIBUTION_ID `
  --query 'Distribution.DomainName' `
  --output text

Write-Host "Domain CloudFront: $CF_DOMAIN"

# Sauvegarder les informations CloudFront
@"
`$CF_DISTRIBUTION_ID = '$CF_DISTRIBUTION_ID'
`$CF_DOMAIN = '$CF_DOMAIN'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8

Write-Host "✓ CloudFront distribution créée!"
Write-Host "URL du frontend: https://$CF_DOMAIN"
```

---

## Partie 8: Déploiement de l'Application (45 min)

### Étape 8.1: Préparer le code de l'application backend

```powershell
# Créer la structure du projet localement
$projectDir = "$env:USERPROFILE\devops-project"
New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
New-Item -ItemType Directory -Path "$projectDir\backend" -Force | Out-Null

# Créer le fichier package.json
$packageJson = @"
{
  "name": "devops-todo-api",
  "version": "1.0.0",
  "description": "API REST pour l'application Todo DevOps",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
"@

$packageJson | Out-File -FilePath "$projectDir\backend\package.json" -Encoding UTF8

# Créer le fichier server.js
$serverJs = @"
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8000;

// Middleware
app.use(cors());
app.use(express.json());

// Configuration de la base de données
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

// Initialiser la base de données
async function initDB() {
  try {
    await pool.query(``
      CREATE TABLE IF NOT EXISTS todos (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ``);
    console.log('Base de données initialisée');
  } catch (err) {
    console.error('Erreur d\'initialisation de la BD:', err);
  }
}

initDB();

// Routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// GET tous les todos
app.get('/api/todos', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM todos ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET un todo par ID
app.get('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM todos WHERE id = `$1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo non trouvé' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST créer un todo
app.post('/api/todos', async (req, res) => {
  try {
    const { title, description, completed } = req.body;
    const result = await pool.query(
      'INSERT INTO todos (title, description, completed) VALUES (`$1, `$2, `$3) RETURNING *',
      [title, description || '', completed || false]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT mettre à jour un todo
app.put('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, completed } = req.body;
    
    const result = await pool.query(
      'UPDATE todos SET title = `$1, description = `$2, completed = `$3, updated_at = CURRENT_TIMESTAMP WHERE id = `$4 RETURNING *',
      [title, description, completed, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo non trouvé' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE supprimer un todo
app.delete('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM todos WHERE id = `$1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Todo non trouvé' });
    }
    
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(``API démarrée sur le port `${port}``);
});
"@

$serverJs | Out-File -FilePath "$projectDir\backend\server.js" -Encoding UTF8

# Créer le Dockerfile
$dockerfile = @"
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

EXPOSE 8000

CMD ["node", "server.js"]
"@

$dockerfile | Out-File -FilePath "$projectDir\backend\Dockerfile" -Encoding UTF8

# Créer le docker-compose.yml
$dockerCompose = @"
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    env_file:
      - .env
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
"@

$dockerCompose | Out-File -FilePath "$projectDir\backend\docker-compose.yml" -Encoding UTF8

Write-Host "Code backend créé dans: $projectDir\backend"
```

### Étape 8.2: Déployer le backend sur EC2

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer une archive du backend
Compress-Archive -Path "$projectDir\backend\*" -DestinationPath "$env:TEMP\backend.zip" -Force

Write-Host "Archive backend créée"

# Copier les fichiers sur l'instance EC2 (nécessite SCP/WinSCP ou AWS SSM)
# Option 1: Via SSM (recommandé)
Write-Host "Téléchargement du backend sur S3 temporairement..."
aws s3 cp "$env:TEMP\backend.zip" "s3://$LOGS_BUCKET/deployment/backend.zip" --region eu-north-1

# Se connecter à l'instance et déployer
$DEPLOY_COMMANDS = @"
#!/bin/bash
cd /home/ec2-user/app
aws s3 cp s3://$LOGS_BUCKET/deployment/backend.zip backend.zip --region eu-north-1
unzip -o backend.zip -d backend
cd backend
docker-compose down
docker-compose up -d --build
rm ../backend.zip

# Vérifier que le conteneur est démarré
sleep 10
docker-compose ps
docker-compose logs --tail=50
"@

$DEPLOY_COMMANDS | Out-File -FilePath "$env:TEMP\deploy-backend.sh" -Encoding UTF8

# Envoyer le script de déploiement
aws s3 cp "$env:TEMP\deploy-backend.sh" "s3://$LOGS_BUCKET/deployment/deploy-backend.sh" --region eu-north-1

# Exécuter via SSM
$COMMAND_ID = aws ssm send-command `
  --instance-ids $INSTANCE_ID `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['aws s3 cp s3://$LOGS_BUCKET/deployment/deploy-backend.sh /tmp/deploy.sh --region eu-north-1','chmod +x /tmp/deploy.sh','su - ec2-user -c /tmp/deploy.sh']" `
  --region eu-north-1 `
  --query 'Command.CommandId' `
  --output text

Write-Host "Commande de déploiement envoyée: $COMMAND_ID"
Write-Host "Attendez environ 2-3 minutes pour le déploiement..."

# Attendre la fin de l'exécution
Start-Sleep -Seconds 120

# Vérifier le statut
$COMMAND_STATUS = aws ssm get-command-invocation `
  --command-id $COMMAND_ID `
  --instance-id $INSTANCE_ID `
  --region eu-north-1 `
  --query 'Status' `
  --output text

Write-Host "Statut du déploiement: $COMMAND_STATUS"

# Alternative Option 2: Connexion SSH manuelle (si SSM ne fonctionne pas)
Write-Host ""
Write-Host "Si SSM ne fonctionne pas, connectez-vous manuellement via SSH:"
Write-Host "ssh -i `"$env:USERPROFILE\.ssh\devops-keypair.pem`" ec2-user@$INSTANCE_PUBLIC_IP"
Write-Host "Puis exécutez les commandes de déploiement manuellement"
```

### Étape 8.3: Tester le backend

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

Write-Host "Test du backend via l'ALB..."
Write-Host "URL: http://$ALB_DNS/api/health"

# Attendre que le Target Group soit healthy
Write-Host "Vérification de l'état du Target Group..."
Start-Sleep -Seconds 30

$healthStatus = aws elbv2 describe-target-health `
  --target-group-arn $TG_ARN `
  --region eu-north-1 `
  --query 'TargetHealthDescriptions[0].TargetHealth.State' `
  --output text

Write-Host "État de la cible: $healthStatus"

if ($healthStatus -eq "healthy") {
    # Tester l'API
    Write-Host "Test de l'API..."
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/health" -Method Get
    Write-Host "Réponse: $($response | ConvertTo-Json)"
} else {
    Write-Host "La cible n'est pas encore healthy. Attendez quelques minutes et réessayez."
}
```

### Étape 8.4: Créer et déployer le frontend

```powershell
# Créer le répertoire frontend
New-Item -ItemType Directory -Path "$projectDir\frontend" -Force | Out-Null

# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer index.html
$indexHtml = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Todo App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            padding: 30px;
        }
        
        h1 {
            color: #333;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #666;
            margin-bottom: 30px;
        }
        
        .add-todo {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        
        input, textarea {
            flex: 1;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 5px;
            font-size: 14px;
        }
        
        input:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        button {
            padding: 12px 24px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: background 0.3s;
        }
        
        button:hover {
            background: #5568d3;
        }
        
        .todo-list {
            list-style: none;
        }
        
        .todo-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 15px;
            transition: transform 0.2s;
        }
        
        .todo-item:hover {
            transform: translateX(5px);
        }
        
        .todo-item.completed {
            opacity: 0.6;
        }
        
        .todo-item.completed .todo-title {
            text-decoration: line-through;
        }
        
        .todo-checkbox {
            width: 20px;
            height: 20px;
            cursor: pointer;
        }
        
        .todo-content {
            flex: 1;
        }
        
        .todo-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 5px;
        }
        
        .todo-description {
            color: #666;
            font-size: 14px;
        }
        
        .todo-actions button {
            padding: 8px 16px;
            font-size: 12px;
            background: #dc3545;
        }
        
        .todo-actions button:hover {
            background: #c82333;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #666;
        }
        
        .error {
            background: #fee;
            color: #c00;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 DevOps Todo App</h1>
        <p class="subtitle">Application de gestion de tâches - Infrastructure AWS</p>
        
        <div id="error" class="error" style="display: none;"></div>
        
        <div class="add-todo">
            <input type="text" id="todoTitle" placeholder="Titre de la tâche..." />
            <input type="text" id="todoDescription" placeholder="Description (optionnel)..." />
            <button onclick="addTodo()">Ajouter</button>
        </div>
        
        <div id="loading" class="loading" style="display: none;">Chargement...</div>
        <ul id="todoList" class="todo-list"></ul>
    </div>

    <script>
        const API_URL = 'http://$ALB_DNS/api';
        
        async function fetchTodos() {
            try {
                document.getElementById('loading').style.display = 'block';
                const response = await fetch(``${API_URL}/todos``);
                const todos = await response.json();
                renderTodos(todos);
                document.getElementById('loading').style.display = 'none';
            } catch (error) {
                showError('Erreur lors du chargement des tâches: ' + error.message);
                document.getElementById('loading').style.display = 'none';
            }
        }
        
        function renderTodos(todos) {
            const list = document.getElementById('todoList');
            list.innerHTML = '';
            
            todos.forEach(todo => {
                const li = document.createElement('li');
                li.className = 'todo-item' + (todo.completed ? ' completed' : '');
                li.innerHTML = ``
                    <input type="checkbox" class="todo-checkbox" 
                           `${todo.completed ? 'checked' : ''}
                           onchange="toggleTodo(`${todo.id}, this.checked)">
                    <div class="todo-content">
                        <div class="todo-title">`${escapeHtml(todo.title)}</div>
                        <div class="todo-description">`${escapeHtml(todo.description || '')}</div>
                    </div>
                    <div class="todo-actions">
                        <button onclick="deleteTodo(`${todo.id})">Supprimer</button>
                    </div>
                ``;
                list.appendChild(li);
            });
        }
        
        async function addTodo() {
            const title = document.getElementById('todoTitle').value.trim();
            const description = document.getElementById('todoDescription').value.trim();
            
            if (!title) {
                showError('Le titre est obligatoire');
                return;
            }
            
            try {
                const response = await fetch(``${API_URL}/todos``, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ title, description, completed: false })
                });
                
                if (response.ok) {
                    document.getElementById('todoTitle').value = '';
                    document.getElementById('todoDescription').value = '';
                    fetchTodos();
                    hideError();
                }
            } catch (error) {
                showError('Erreur lors de l\'ajout: ' + error.message);
            }
        }
        
        async function toggleTodo(id, completed) {
            try {
                const response = await fetch(``${API_URL}/todos/`${id}``, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ completed })
                });
                
                if (response.ok) {
                    fetchTodos();
                }
            } catch (error) {
                showError('Erreur lors de la mise à jour: ' + error.message);
            }
        }
        
        async function deleteTodo(id) {
            if (!confirm('Êtes-vous sûr de vouloir supprimer cette tâche ?')) return;
            
            try {
                const response = await fetch(``${API_URL}/todos/`${id}``, {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    fetchTodos();
                }
            } catch (error) {
                showError('Erreur lors de la suppression: ' + error.message);
            }
        }
        
        function showError(message) {
            const errorDiv = document.getElementById('error');
            errorDiv.textContent = message;
            errorDiv.style.display = 'block';
        }
        
        function hideError() {
            document.getElementById('error').style.display = 'none';
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        // Charger les todos au démarrage
        fetchTodos();
        
        // Rafraîchir toutes les 30 secondes
        setInterval(fetchTodos, 30000);
        
        // Permettre d'ajouter avec Enter
        document.getElementById('todoTitle').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') addTodo();
        });
        
        document.getElementById('todoDescription').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') addTodo();
        });
    </script>
</body>
</html>
"@

$indexHtml | Out-File -FilePath "$projectDir\frontend\index.html" -Encoding UTF8

# Uploader le frontend sur S3
Write-Host "Déploiement du frontend sur S3..."
aws s3 cp "$projectDir\frontend\index.html" "s3://$FRONTEND_BUCKET/index.html" `
  --content-type "text/html" `
  --region eu-north-1

Write-Host "✓ Frontend déployé!"
Write-Host "URL S3: http://$FRONTEND_BUCKET.s3-website.eu-north-1.amazonaws.com"
Write-Host "URL CloudFront: https://$CF_DOMAIN"
```

---

## Partie 9: Monitoring avec CloudWatch (30 min)

### Étape 9.1: Créer un groupe de logs CloudWatch

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

# Créer le groupe de logs
aws logs create-log-group `
  --log-group-name /aws/application/devops-todo-app `
  --region eu-north-1

Write-Host "Groupe de logs créé"

# Définir la rétention
aws logs put-retention-policy `
  --log-group-name /aws/application/devops-todo-app `
  --retention-in-days 7 `
  --region eu-north-1

Write-Host "Politique de rétention configurée (7 jours)"
```

### Étape 9.2: Configurer CloudWatch Logs sur EC2

```powershell
# Configuration de CloudWatch Agent
$CW_CONFIG = @"
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/application/devops-todo-app",
            "log_stream_name": "{instance_id}/system",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
"@

$CW_CONFIG | Out-File -FilePath "$env:TEMP\cloudwatch-config.json" -Encoding UTF8

# Uploader la configuration sur S3
aws s3 cp "$env:TEMP\cloudwatch-config.json" "s3://$LOGS_BUCKET/cloudwatch-config.json" --region eu-north-1

# Configurer via SSM
$CONFIGURE_CW = @"
#!/bin/bash
aws s3 cp s3://$LOGS_BUCKET/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/config.json --region eu-north-1
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
"@

$CONFIGURE_CW | Out-File -FilePath "$env:TEMP\configure-cw.sh" -Encoding UTF8
aws s3 cp "$env:TEMP\configure-cw.sh" "s3://$LOGS_BUCKET/deployment/configure-cw.sh" --region eu-north-1

# Exécuter la configuration
aws ssm send-command `
  --instance-ids $INSTANCE_ID `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['aws s3 cp s3://$LOGS_BUCKET/deployment/configure-cw.sh /tmp/configure-cw.sh --region eu-north-1','chmod +x /tmp/configure-cw.sh','bash /tmp/configure-cw.sh']" `
  --region eu-north-1

Write-Host "Configuration CloudWatch Logs envoyée"
```

### Étape 9.3: Créer des alarmes CloudWatch

```powershell
# Créer un topic SNS pour les alertes
$SNS_TOPIC_ARN = aws sns create-topic `
  --name devops-alerts `
  --region eu-north-1 `
  --query 'TopicArn' `
  --output text

Write-Host "Topic SNS créé: $SNS_TOPIC_ARN"

# S'abonner au topic (remplacez par votre email)
$YOUR_EMAIL = Read-Host "Entrez votre adresse email pour les alertes"
aws sns subscribe `
  --topic-arn $SNS_TOPIC_ARN `
  --protocol email `
  --notification-endpoint $YOUR_EMAIL `
  --region eu-north-1

Write-Host "Abonnement créé. Vérifiez votre email pour confirmer!"

# Alarme CPU EC2
aws cloudwatch put-metric-alarm `
  --alarm-name devops-ec2-cpu-high `
  --alarm-description "Alarme quand CPU > 80%" `
  --metric-name CPUUtilization `
  --namespace AWS/EC2 `
  --statistic Average `
  --period 300 `
  --threshold 80 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 2 `
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" `
  --region eu-north-1 `
  --alarm-actions $SNS_TOPIC_ARN

Write-Host "✓ Alarme CPU créée"

# Alarme RDS
aws cloudwatch put-metric-alarm `
  --alarm-name devops-rds-cpu-high `
  --alarm-description "Alarme quand CPU RDS > 80%" `
  --metric-name CPUUtilization `
  --namespace AWS/RDS `
  --statistic Average `
  --period 300 `
  --threshold 80 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 2 `
  --dimensions "Name=DBInstanceIdentifier,Value=devops-postgres-db" `
  --region eu-north-1 `
  --alarm-actions $SNS_TOPIC_ARN

Write-Host "✓ Alarme RDS créée"

# Alarme ALB
aws cloudwatch put-metric-alarm `
  --alarm-name devops-alb-target-errors `
  --alarm-description "Alarme quand trop d'erreurs 5XX" `
  --metric-name HTTPCode_Target_5XX_Count `
  --namespace AWS/ApplicationELB `
  --statistic Sum `
  --period 300 `
  --threshold 10 `
  --comparison-operator GreaterThanThreshold `
  --evaluation-periods 1 `
  --treat-missing-data notBreaching `
  --region eu-north-1 `
  --alarm-actions $SNS_TOPIC_ARN

Write-Host "✓ Alarme ALB créée"

# Sauvegarder
@"
`$SNS_TOPIC_ARN = '$SNS_TOPIC_ARN'
"@ | Out-File -FilePath $configPath -Append -Encoding UTF8
```

### Étape 9.4: Créer un Dashboard CloudWatch

```powershell
# Créer le dashboard
$DASHBOARD_BODY = @"
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization", { "stat": "Average", "dimensions": {"InstanceId": "$INSTANCE_ID"} } ],
          [ ".", "NetworkIn", { "stat": "Sum" } ],
          [ ".", "NetworkOut", { "stat": "Sum" } ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-north-1",
        "title": "EC2 Instance Metrics",
        "yAxis": {
          "left": {
            "label": "Percent / Bytes"
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/RDS", "DatabaseConnections", { "dimensions": {"DBInstanceIdentifier": "devops-postgres-db"} } ],
          [ ".", "CPUUtilization" ],
          [ ".", "FreeableMemory", { "stat": "Average" } ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-north-1",
        "title": "RDS Metrics"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", { "stat": "Sum" } ],
          [ ".", "TargetResponseTime", { "stat": "Average" } ],
          [ ".", "HTTPCode_Target_2XX_Count", { "stat": "Sum" } ],
          [ ".", "HTTPCode_Target_5XX_Count", { "stat": "Sum" } ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-north-1",
        "title": "Application Load Balancer"
      }
    },
    {
      "type": "log",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "query": "SOURCE '/aws/application/devops-todo-app'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 20",
        "region": "eu-north-1",
        "title": "Application Logs (Recent)",
        "stacked": false
      }
    }
  ]
}
"@

$DASHBOARD_BODY | Out-File -FilePath "$env:TEMP\dashboard.json" -Encoding UTF8

aws cloudwatch put-dashboard `
  --dashboard-name devops-infrastructure-dashboard `
  --dashboard-body "file://$env:TEMP\dashboard.json" `
  --region eu-north-1

Write-Host "✓ Dashboard CloudWatch créé"
Write-Host "Accès: https://console.aws.amazon.com/cloudwatch/home?region=eu-north-1#dashboards:name=devops-infrastructure-dashboard"
```

---

## Partie 10: Tests de l'Infrastructure (30 min)

### Étape 10.1: Tests Fonctionnels de l'API

```powershell
# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

Write-Host "=== Tests de l'API DevOps Todo ==="
Write-Host ""

# Test 1: Health Check
Write-Host "Test 1: Health Check"
try {
    $healthResponse = Invoke-RestMethod -Uri "http://$ALB_DNS/api/health" -Method Get
    Write-Host "✓ Health check réussi"
    Write-Host "  Réponse: $($healthResponse | ConvertTo-Json -Compress)"
} catch {
    Write-Host "✗ Health check échoué: $_"
}
Write-Host ""

# Test 2: Créer une tâche
Write-Host "Test 2: Créer une tâche"
try {
    $createBody = @{
        title = "Test automatique"
        description = "Tâche créée par le script de test"
        completed = $false
    } | ConvertTo-Json

    $createResponse = Invoke-RestMethod -Uri "http://$ALB_DNS/api/todos" `
        -Method Post `
        -ContentType "application/json" `
        -Body $createBody

    $TODO_ID = $createResponse.id
    Write-Host "✓ Tâche créée (ID: $TODO_ID)"
    Write-Host "  Réponse: $($createResponse | ConvertTo-Json -Compress)"
} catch {
    Write-Host "✗ Échec de la création de tâche: $_"
}
Write-Host ""

# Test 3: Lister toutes les tâches
Write-Host "Test 3: Lister toutes les tâches"
try {
    $listResponse = Invoke-RestMethod -Uri "http://$ALB_DNS/api/todos" -Method Get
    $TODO_COUNT = $listResponse.Count
    Write-Host "✓ Récupération de $TODO_COUNT tâche(s)"
} catch {
    Write-Host "✗ Échec de la récupération: $_"
}
Write-Host ""

# Test 4: Récupérer une tâche spécifique
if ($TODO_ID) {
    Write-Host "Test 4: Récupérer une tâche spécifique (ID: $TODO_ID)"
    try {
        $getResponse = Invoke-RestMethod -Uri "http://$ALB_DNS/api/todos/$TODO_ID" -Method Get
        Write-Host "✓ Tâche récupérée"
    } catch {
        Write-Host "✗ Échec de la récupération: $_"
    }
    Write-Host ""

    # Test 5: Mettre à jour une tâche
    Write-Host "Test 5: Mettre à jour une tâche"
    try {
        $updateBody = @{
            title = "Test automatique (modifié)"
            description = "Tâche mise à jour par le script de test"
            completed = $true
        } | ConvertTo-Json

        $updateResponse = Invoke-RestMethod -Uri "http://$ALB_DNS/api/todos/$TODO_ID" `
            -Method Put `
            -ContentType "application/json" `
            -Body $updateBody

        Write-Host "✓ Tâche mise à jour"
        Write-Host "  Réponse: $($updateResponse | ConvertTo-Json -Compress)"
    } catch {
        Write-Host "✗ Échec de la mise à jour: $_"
    }
    Write-Host ""

    # Test 6: Supprimer une tâche
    Write-Host "Test 6: Supprimer une tâche"
    try {
        Invoke-RestMethod -Uri "http://$ALB_DNS/api/todos/$TODO_ID" -Method Delete
        Write-Host "✓ Tâche supprimée"
    } catch {
        Write-Host "✗ Échec de la suppression: $_"
    }
    Write-Host ""
}

Write-Host "=== Tests terminés ==="
```

### Étape 10.2: Vérifier les Logs

```powershell
Write-Host "=== Accès aux logs ==="
Write-Host "Logs CloudWatch:"
Write-Host "https://console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/`$252Faws`$252Fapplication`$252Fdevops-todo-app"
Write-Host ""
Write-Host "Dashboard:"
Write-Host "https://console.aws.amazon.com/cloudwatch/home?region=eu-north-1#dashboards:name=devops-infrastructure-dashboard"
```

---

## Partie 11: Script de Nettoyage (Clean-up)

```powershell
# Script pour supprimer toutes les ressources
Write-Host "=== Script de nettoyage de l'infrastructure AWS ==="
Write-Host "ATTENTION: Ce script va supprimer TOUTES les ressources créées!"
$confirm = Read-Host "Voulez-vous continuer? (oui/non)"

if ($confirm -ne "oui") {
    Write-Host "Nettoyage annulé"
    exit
}

# Charger la configuration
. "$env:USERPROFILE\devops-aws-config.ps1"

Write-Host "Début du nettoyage..."

# 1. Supprimer la distribution CloudFront
if ($CF_DISTRIBUTION_ID) {
    Write-Host "Désactivation de CloudFront..."
    try {
        # Récupérer la config actuelle
        $cfConfig = aws cloudfront get-distribution-config --id $CF_DISTRIBUTION_ID --region eu-north-1 | ConvertFrom-Json
        $etag = aws cloudfront get-distribution-config --id $CF_DISTRIBUTION_ID --region eu-north-1 --query 'ETag' --output text
        
        # Désactiver
        $cfConfig.DistributionConfig.Enabled = $false
        $cfConfig.DistributionConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath "$env:TEMP\cf-disable.json" -Encoding UTF8
        
        aws cloudfront update-distribution --id $CF_DISTRIBUTION_ID --if-match $etag --distribution-config "file://$env:TEMP\cf-disable.json" --region eu-north-1
        Write-Host "CloudFront désactivée (sera supprimée automatiquement après quelques minutes)"
    } catch {
        Write-Host "Erreur CloudFront: $_"
    }
}

# 2. Vider et supprimer les buckets S3
if ($FRONTEND_BUCKET) {
    Write-Host "Suppression du bucket frontend..."
    aws s3 rm "s3://$FRONTEND_BUCKET" --recursive --region eu-north-1
    aws s3api delete-bucket --bucket $FRONTEND_BUCKET --region eu-north-1
}

if ($LOGS_BUCKET) {
    Write-Host "Suppression du bucket logs..."
    aws s3 rm "s3://$LOGS_BUCKET" --recursive --region eu-north-1
    aws s3api delete-bucket --bucket $LOGS_BUCKET --region eu-north-1
}

# 3. Supprimer l'ALB
if ($ALB_ARN) {
    Write-Host "Suppression de l'ALB..."
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region eu-north-1
    Start-Sleep -Seconds 30
}

if ($TG_ARN) {
    Write-Host "Suppression du Target Group..."
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region eu-north-1
}

# 4. Terminer l'instance EC2
if ($INSTANCE_ID) {
    Write-Host "Terminaison de l'instance EC2..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region eu-north-1
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region eu-north-1
}

# 5. Supprimer la base de données RDS
Write-Host "Suppression de l'instance RDS..."
aws rds delete-db-instance `
    --db-instance-identifier devops-postgres-db `
    --skip-final-snapshot `
    --region eu-north-1

# 6. Supprimer le NAT Gateway
if ($NAT_GW_ID) {
    Write-Host "Suppression du NAT Gateway..."
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region eu-north-1
    Start-Sleep -Seconds 60
}

# 7. Libérer l'Elastic IP
if ($EIP_ALLOC_ID) {
    Write-Host "Libération de l'Elastic IP..."
    aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region eu-north-1
}

# 8. Supprimer l'Internet Gateway
if ($IGW_ID) {
    Write-Host "Suppression de l'Internet Gateway..."
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region eu-north-1
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region eu-north-1
}

# 9. Supprimer les tables de routage
if ($PUBLIC_RT_ID) {
    Write-Host "Suppression des tables de routage..."
    aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID --region eu-north-1
}

if ($PRIVATE_RT_ID) {
    aws ec2 delete-route-table --route-table-id $PRIVATE_RT_ID --region eu-north-1
}

# 10. Supprimer les subnets
Write-Host "Suppression des subnets..."
if ($PUBLIC_SUBNET_1) { aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1 --region eu-north-1 }
if ($PUBLIC_SUBNET_2) { aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2 --region eu-north-1 }
if ($PRIVATE_SUBNET_1) { aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1 --region eu-north-1 }
if ($PRIVATE_SUBNET_2) { aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2 --region eu-north-1 }

# 11. Supprimer les Security Groups
Start-Sleep -Seconds 30
Write-Host "Suppression des Security Groups..."
if ($EC2_SG_ID) { aws ec2 delete-security-group --group-id $EC2_SG_ID --region eu-north-1 }
if ($RDS_SG_ID) { aws ec2 delete-security-group --group-id $RDS_SG_ID --region eu-north-1 }
if ($ALB_SG_ID) { aws ec2 delete-security-group --group-id $ALB_SG_ID --region eu-north-1 }

# 12. Supprimer le VPC
if ($VPC_ID) {
    Write-Host "Suppression du VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID --region eu-north-1
}

# 13. Supprimer les ressources IAM
Write-Host "Suppression des ressources IAM..."
aws iam remove-role-from-instance-profile --instance-profile-name devops-ec2-profile --role-name devops-ec2-role
aws iam delete-instance-profile --instance-profile-name devops-ec2-profile
aws iam delete-role-policy --role-name devops-ec2-role --policy-name SecretsManagerAccess
aws iam detach-role-policy --role-name devops-ec2-role --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
aws iam detach-role-policy --role-name devops-ec2-role --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
aws iam delete-role --role-name devops-ec2-role

# 14. Supprimer la clé SSH
Write-Host "Suppression de la paire de clés..."
aws ec2 delete-key-pair --key-name devops-keypair --region eu-north-1

# 15. Supprimer le secret
Write-Host "Suppression du secret..."
aws secretsmanager delete-secret --secret-id devops/db/credentials --force-delete-without-recovery --region eu-north-1

# 16. Supprimer les alarmes et SNS
Write-Host "Suppression des alarmes..."
aws cloudwatch delete-alarms --alarm-names devops-ec2-cpu-high devops-rds-cpu-high devops-alb-target-errors --region eu-north-1

if ($SNS_TOPIC_ARN) {
    aws sns delete-topic --topic-arn $SNS_TOPIC_ARN --region eu-north-1
}

# 17. Supprimer le dashboard
Write-Host "Suppression du dashboard..."
aws cloudwatch delete-dashboards --dashboard-names devops-infrastructure-dashboard --region eu-north-1

# 18. Supprimer le groupe de logs
Write-Host "Suppression du groupe de logs..."
aws logs delete-log-group --log-group-name /aws/application/devops-todo-app --region eu-north-1

# 19. Supprimer le DB Subnet Group
Write-Host "Suppression du DB Subnet Group..."
aws rds delete-db-subnet-group --db-subnet-group-name devops-db-subnet-group --region eu-north-1

Write-Host ""
Write-Host "=== Nettoyage terminé! ==="
Write-Host "Note: La distribution CloudFront peut prendre jusqu'à 15 minutes pour être complètement supprimée"
Write-Host "Vérifiez manuellement dans la console AWS que toutes les ressources ont bien été supprimées"
```

---

## Points d'Attention pour le Free Tier

⚠️ **Services NON inclus dans le Free Tier:**
- Application Load Balancer (~$16/mois)
- NAT Gateway (~$30/mois)
- Données sortantes au-delà de 15 GB/mois

💡 **Optimisations possibles:**
1. Remplacer l'ALB par un Elastic IP directement sur EC2
2. Placer l'EC2 dans un subnet public (pas de NAT Gateway nécessaire)
3. Surveiller les données sortantes

## Prochaines Étapes Possibles

1. **CI/CD avec GitHub Actions** ou GitLab CI
2. **HTTPS avec Let's Encrypt** sur l'ALB
3. **Auto Scaling Group** pour la haute disponibilité
4. **Backups automatisés** avec AWS Backup
5. **Tests de sécurité** avec Trivy/SonarQube
6. **Infrastructure as Code** migration vers Terraform/CloudFormation

## Résumé des URLs importantes

```powershell
# Charger la configuration pour voir toutes vos URLs
. "$env:USERPROFILE\devops-aws-config.ps1"

Write-Host "=== URLs de votre infrastructure ==="
Write-Host "API Backend (ALB): http://$ALB_DNS"
Write-Host "Frontend (CloudFront): https://$CF_DOMAIN"
Write-Host "Frontend (S3): http://$FRONTEND_BUCKET.s3-website.eu-north-1.amazonaws.com"
Write-Host "Dashboard CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=eu-north-1#dashboards:name=devops-infrastructure-dashboard"
Write-Host ""
Write-Host "Instance EC2 IP: $INSTANCE_PUBLIC_IP"
Write-Host "Connexion SSH: ssh -i `"$env:USERPROFILE\.ssh\devops-keypair.pem`" ec2-user@$INSTANCE_PUBLIC_IP"
```

**Bon exercice! 🚀**