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

4. **Configurer AWS CLI**
```bash
# Configurer le profil AWS CLI
aws configure --profile devops-admin
# AWS Access Key ID: [votre clé]
# AWS Secret Access Key: [votre secret]
# Default region name: eu-west-1
# Default output format: json

# Définir ce profil par défaut
export AWS_PROFILE=devops-admin
echo 'export AWS_PROFILE=devops-admin' >> ~/.bashrc
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

**Via AWS CLI:**

```bash
# Créer le VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=devops-vpc},{Key=Environment,Value=training}]' \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC ID: $VPC_ID"

# Activer DNS hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

# Activer DNS support
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support
```

### Étape 2.2: Créer les Subnets

**Via AWS CLI:**

```bash
# Subnet Public 1 (AZ a)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone eu-west-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-public-subnet-1},{Key=Type,Value=Public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Public Subnet 1: $PUBLIC_SUBNET_1"

# Activer l'attribution automatique d'IP publique
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_1 \
  --map-public-ip-on-launch

# Subnet Public 2 (AZ b)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone eu-west-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-public-subnet-2},{Key=Type,Value=Public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Public Subnet 2: $PUBLIC_SUBNET_2"

aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_2 \
  --map-public-ip-on-launch

# Subnet Privé 1 (AZ a)
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.11.0/24 \
  --availability-zone eu-west-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-private-subnet-1},{Key=Type,Value=Private}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Private Subnet 1: $PRIVATE_SUBNET_1"

# Subnet Privé 2 (AZ b)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.12.0/24 \
  --availability-zone eu-west-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=devops-private-subnet-2},{Key=Type,Value=Private}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Private Subnet 2: $PRIVATE_SUBNET_2"
```

### Étape 2.3: Créer et Configurer l'Internet Gateway

```bash
# Créer Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=devops-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Internet Gateway ID: $IGW_ID"

# Attacher l'IGW au VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

### Étape 2.4: Créer le NAT Gateway

```bash
# Allouer une Elastic IP pour le NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=devops-nat-eip}]' \
  --query 'AllocationId' \
  --output text)

echo "Elastic IP Allocation ID: $EIP_ALLOC_ID"

# Créer le NAT Gateway dans le subnet public 1
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_1 \
  --allocation-id $EIP_ALLOC_ID \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=devops-nat-gateway}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "NAT Gateway ID: $NAT_GW_ID"

# Attendre que le NAT Gateway soit disponible (environ 2-3 minutes)
echo "Attente de la disponibilité du NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
echo "NAT Gateway disponible!"
```

### Étape 2.5: Créer les Tables de Routage

```bash
# Table de routage publique
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=devops-public-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Public Route Table ID: $PUBLIC_RT_ID"

# Ajouter une route vers Internet via l'IGW
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associer les subnets publics à la table de routage publique
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_1

aws ec2 associate-route-table \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_2

# Table de routage privée
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=devops-private-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Private Route Table ID: $PRIVATE_RT_ID"

# Ajouter une route vers Internet via le NAT Gateway
aws ec2 create-route \
  --route-table-id $PRIVATE_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID

# Associer les subnets privés à la table de routage privée
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_RT_ID \
  --subnet-id $PRIVATE_SUBNET_1

aws ec2 associate-route-table \
  --route-table-id $PRIVATE_RT_ID \
  --subnet-id $PRIVATE_SUBNET_2
```

### Étape 2.6: Sauvegarder les IDs

```bash
# Créer un fichier pour sauvegarder tous les IDs
cat > ~/devops-aws-ids.sh << EOF
#!/bin/bash
# IDs de l'infrastructure AWS DevOps
export VPC_ID="$VPC_ID"
export PUBLIC_SUBNET_1="$PUBLIC_SUBNET_1"
export PUBLIC_SUBNET_2="$PUBLIC_SUBNET_2"
export PRIVATE_SUBNET_1="$PRIVATE_SUBNET_1"
export PRIVATE_SUBNET_2="$PRIVATE_SUBNET_2"
export IGW_ID="$IGW_ID"
export NAT_GW_ID="$NAT_GW_ID"
export PUBLIC_RT_ID="$PUBLIC_RT_ID"
export PRIVATE_RT_ID="$PRIVATE_RT_ID"
export EIP_ALLOC_ID="$EIP_ALLOC_ID"
EOF

chmod +x ~/devops-aws-ids.sh
source ~/devops-aws-ids.sh

echo "IDs sauvegardés dans ~/devops-aws-ids.sh"
```

---

## Partie 3: Security Groups (30 min)

### Étape 3.1: Créer les Security Groups

```bash
# Charger les variables si nécessaire
source ~/devops-aws-ids.sh

# Security Group pour l'ALB (Load Balancer)
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name devops-alb-sg \
  --description "Security group for Application Load Balancer" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-alb-sg}]' \
  --query 'GroupId' \
  --output text)

echo "ALB Security Group ID: $ALB_SG_ID"

# Règles d'entrée pour ALB (HTTP et HTTPS)
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTP from Internet"}]' \
    IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTPS from Internet"}]'

# Security Group pour EC2 Backend
BACKEND_SG_ID=$(aws ec2 create-security-group \
  --group-name devops-backend-sg \
  --description "Security group for backend EC2 instances" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-backend-sg}]' \
  --query 'GroupId' \
  --output text)

echo "Backend Security Group ID: $BACKEND_SG_ID"

# Règles d'entrée pour Backend
# SSH depuis n'importe où (à restreindre en production)
aws ec2 authorize-security-group-ingress \
  --group-id $BACKEND_SG_ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="SSH from anywhere"}]'

# HTTP pour l'API depuis l'ALB
aws ec2 authorize-security-group-ingress \
  --group-id $BACKEND_SG_ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=8080,ToPort=8080,UserIdGroupPairs="[{GroupId=$ALB_SG_ID,Description=\"API from ALB\"}]"

# Security Group pour RDS
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name devops-rds-sg \
  --description "Security group for RDS PostgreSQL" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=devops-rds-sg}]' \
  --query 'GroupId' \
  --output text)

echo "RDS Security Group ID: $RDS_SG_ID"

# Règle d'entrée pour RDS (PostgreSQL depuis Backend uniquement)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=5432,ToPort=5432,UserIdGroupPairs="[{GroupId=$BACKEND_SG_ID,Description=\"PostgreSQL from Backend\"}]"

# Sauvegarder les nouveaux IDs
cat >> ~/devops-aws-ids.sh << EOF
export ALB_SG_ID="$ALB_SG_ID"
export BACKEND_SG_ID="$BACKEND_SG_ID"
export RDS_SG_ID="$RDS_SG_ID"
EOF

source ~/devops-aws-ids.sh
```

---

## Partie 4: Base de Données RDS PostgreSQL (30 min)

### Étape 4.1: Créer un Subnet Group pour RDS

```bash
source ~/devops-aws-ids.sh

# Créer le DB Subnet Group
aws rds create-db-subnet-group \
  --db-subnet-group-name devops-db-subnet-group \
  --db-subnet-group-description "Subnet group for DevOps RDS" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
  --tags "Key=Name,Value=devops-db-subnet-group"

echo "DB Subnet Group créé"
```

### Étape 4.2: Générer un Mot de Passe Sécurisé

```bash
# Générer un mot de passe aléatoire sécurisé
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "/@\"\\'")
echo "Mot de passe généré (à sauvegarder): $DB_PASSWORD"

# Sauvegarder temporairement
echo "export DB_PASSWORD='$DB_PASSWORD'" >> ~/devops-aws-ids.sh
```

### Étape 4.3: Créer l'Instance RDS

```bash
# Créer l'instance RDS PostgreSQL
aws rds create-db-instance \
  --db-instance-identifier devops-postgres-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username dbadmin \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --storage-type gp2 \
  --db-subnet-group-name devops-db-subnet-group \
  --vpc-security-group-ids $RDS_SG_ID \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --db-name todoapp \
  --no-publicly-accessible \
  --tags "Key=Name,Value=devops-postgres" "Key=Environment,Value=training"

echo "Instance RDS en cours de création... (cela prend 5-10 minutes)"

# Attendre que l'instance soit disponible
aws rds wait db-instance-available --db-instance-identifier devops-postgres-db

echo "Instance RDS disponible!"

# Récupérer l'endpoint de la base de données
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier devops-postgres-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

DB_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier devops-postgres-db \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text)

echo "DB Endpoint: $DB_ENDPOINT"
echo "DB Port: $DB_PORT"

# Sauvegarder l'endpoint
cat >> ~/devops-aws-ids.sh << EOF
export DB_ENDPOINT="$DB_ENDPOINT"
export DB_PORT="$DB_PORT"
EOF
```

### Étape 4.4: Stocker les Credentials dans Secrets Manager

```bash
source ~/devops-aws-ids.sh

# Créer le secret
SECRET_ARN=$(aws secretsmanager create-secret \
  --name devops/database/credentials \
  --description "Database credentials for DevOps application" \
  --secret-string "{\"username\":\"dbadmin\",\"password\":\"$DB_PASSWORD\",\"host\":\"$DB_ENDPOINT\",\"port\":$DB_PORT,\"dbname\":\"todoapp\"}" \
  --tags "Key=Name,Value=devops-db-secret" \
  --query 'ARN' \
  --output text)

echo "Secret ARN: $SECRET_ARN"

cat >> ~/devops-aws-ids.sh << EOF
export SECRET_ARN="$SECRET_ARN"
EOF
```

---

## Partie 5: Rôles IAM pour EC2 (20 min)

### Étape 5.1: Créer le Rôle IAM

```bash
# Créer la politique de confiance pour EC2
cat > /tmp/ec2-trust-policy.json << 'EOF'
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
EOF

# Créer le rôle IAM
aws iam create-role \
  --role-name devops-backend-role \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
  --description "IAM role for DevOps backend EC2 instances"

echo "Rôle IAM créé"

# Attacher les politiques nécessaires
# 1. Secrets Manager (lecture)
aws iam attach-role-policy \
  --role-name devops-backend-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

# 2. S3 (pour logs et artefacts)
aws iam attach-role-policy \
  --role-name devops-backend-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# 3. CloudWatch (pour monitoring)
aws iam attach-role-policy \
  --role-name devops-backend-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# Créer le profil d'instance
aws iam create-instance-profile \
  --instance-profile-name devops-backend-profile

# Attacher le rôle au profil
aws iam add-role-to-instance-profile \
  --instance-profile-name devops-backend-profile \
  --role-name devops-backend-role

echo "Profil d'instance créé et configuré"

# Attendre un peu pour la propagation
sleep 10
```

---

## Partie 6: Instance EC2 Backend (45 min)

### Étape 6.1: Créer une Key Pair SSH

```bash
# Créer la paire de clés
aws ec2 create-key-pair \
  --key-name devops-keypair \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-keypair.pem

# Définir les bonnes permissions
chmod 400 ~/.ssh/devops-keypair.pem

echo "Key pair créée: ~/.ssh/devops-keypair.pem"
```

### Étape 6.2: Créer le Script User Data

```bash
source ~/devops-aws-ids.sh

# Créer le script user-data
cat > /tmp/user-data.sh << 'USERDATA'
#!/bin/bash
set -e

# Log toutes les actions
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Début de la configuration de l'instance ==="
date

# Mise à jour du système
echo "Mise à jour du système..."
dnf update -y

# Installation de Docker
echo "Installation de Docker..."
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Installation de Docker Compose
echo "Installation de Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Installation de Git
echo "Installation de Git..."
dnf install -y git

# Installation du CloudWatch Agent
echo "Installation du CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm -f ./amazon-cloudwatch-agent.rpm

# Installation d'outils utiles
dnf install -y htop vim wget curl jq

# Créer le répertoire de l'application
echo "Création des répertoires..."
mkdir -p /home/ec2-user/app
mkdir -p /home/ec2-user/app/logs
chown -R ec2-user:ec2-user /home/ec2-user/app

# Script pour récupérer les credentials de la base de données
cat > /home/ec2-user/app/get-db-credentials.sh << 'EOF'
#!/bin/bash
REGION=$(ec2-metadata --availability-zone | sed 's/placement: //' | sed 's/.$//')
aws secretsmanager get-secret-value \
  --secret-id devops/database/credentials \
  --region $REGION \
  --query SecretString \
  --output text > /home/ec2-user/app/db-credentials.json
chmod 600 /home/ec2-user/app/db-credentials.json
EOF

chmod +x /home/ec2-user/app/get-db-credentials.sh
chown ec2-user:ec2-user /home/ec2-user/app/get-db-credentials.sh

# Exécuter le script pour récupérer les credentials
echo "Récupération des credentials de la base de données..."
su - ec2-user -c "/home/ec2-user/app/get-db-credentials.sh"

# Configuration du CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/devops-backend",
            "log_stream_name": "{instance_id}/messages",
            "retention_in_days": 7
          },
          {
            "file_path": "/home/ec2-user/app/logs/app.log",
            "log_group_name": "/aws/application/devops-todo-app",
            "log_stream_name": "{instance_id}/application",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "DevOps/Application",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          }
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Démarrer le CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "=== Configuration de l'instance terminée ==="
date
echo "Instance prête!" > /var/log/user-data-complete.log
USERDATA
```

### Étape 6.3: Lancer l'Instance EC2

```bash
source ~/devops-aws-ids.sh

# Récupérer l'AMI Amazon Linux 2023 la plus récente
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"

# Lancer l'instance EC2
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name devops-keypair \
  --subnet-id $PUBLIC_SUBNET_1 \
  --security-group-ids $BACKEND_SG_ID \
  --iam-instance-profile Name=devops-backend-profile \
  --user-data file:///tmp/user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-backend-server},{Key=Environment,Value=training}]' \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp2"}}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# Attendre que l'instance soit en cours d'exécution
echo "Attente du démarrage de l'instance..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance en cours d'exécution!"

# Récupérer l'IP publique
INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "IP Publique de l'instance: $INSTANCE_PUBLIC_IP"

# Sauvegarder les informations
cat >> ~/devops-aws-ids.sh << EOF
export INSTANCE_ID="$INSTANCE_ID"
export INSTANCE_PUBLIC_IP="$INSTANCE_PUBLIC_IP"
EOF

source ~/devops-aws-ids.sh

# Attendre 2 minutes pour que le user-data se termine
echo "Attente de la fin de l'initialisation de l'instance (2 minutes)..."
sleep 120
```

### Étape 6.4: Vérifier l'Installation

```bash
source ~/devops-aws-ids.sh

# Se connecter à l'instance
ssh -i ~/.ssh/devops-keypair.pem ec2-user@$INSTANCE_PUBLIC_IP << 'ENDSSH'
# Vérifier Docker
docker --version

# Vérifier Docker Compose
docker-compose --version

# Vérifier les credentials de la base de données
if [ -f /home/ec2-user/app/db-credentials.json ]; then
    echo "✓ Credentials de la base de données récupérés"
    cat /home/ec2-user/app/db-credentials.json | jq .
else
    echo "✗ Erreur: credentials non trouvés"
fi

# Vérifier les logs user-data
tail -20 /var/log/user-data.log
ENDSSH
```

---

## Partie 7: Application Backend (30 minutes)

### Étape 7.1: Déployer l'Application sur EC2

```bash
# Sur votre machine locale
cd ~/devops-todo-app

# Créer une archive du code backend
tar -czf backend.tar.gz app/backend/

# Copier l'archive sur l'instance EC2
source ~/devops-aws-ids.sh
scp -i ~/.ssh/devops-keypair.pem backend.tar.gz ec2-user@$INSTANCE_PUBLIC_IP:/home/ec2-user/

# Se connecter à l'instance et déployer
ssh -i ~/.ssh/devops-keypair.pem ec2-user@$INSTANCE_PUBLIC_IP << 'ENDSSH'
# Extraire l'archive
cd /home/ec2-user/app
tar -xzf ../backend.tar.gz --strip-components=1
rm -f ../backend.tar.gz

# Aller dans le répertoire backend
cd backend

# Build et démarrage avec Docker Compose
docker-compose build
docker-compose up -d

# Attendre quelques secondes
sleep 5

# Vérifier que le conteneur tourne
docker-compose ps

# Voir les logs
docker-compose logs

# Tester l'API
curl http://localhost:8080/api/health
ENDSSH

echo ""
echo "✓ Application backend déployée!"
echo "Tester: curl http://$INSTANCE_PUBLIC_IP:8080/api/health"
```

---

## Partie 8: Application Load Balancer (30 min)

### Étape 8.1: Créer un Target Group

```bash
source ~/devops-aws-ids.sh

# Créer le Target Group
TG_ARN=$(aws elbv2 create-target-group \
  --name devops-backend-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --health-check-enabled \
  --health-check-path /api/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2 \
  --matcher HttpCode=200 \
  --tags "Key=Name,Value=devops-backend-tg" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"

# Enregistrer l'instance EC2 dans le Target Group
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID

echo "Instance enregistrée dans le Target Group"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export TG_ARN="$TG_ARN"
EOF
```

### Étape 8.2: Créer l'Application Load Balancer

```bash
source ~/devops-aws-ids.sh

# Créer l'ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name devops-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags "Key=Name,Value=devops-alb" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB ARN: $ALB_ARN"

# Attendre que l'ALB soit actif
echo "Attente de la création de l'ALB..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
echo "ALB actif!"

# Récupérer le DNS name de l'ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS Name: $ALB_DNS"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export ALB_ARN="$ALB_ARN"
export ALB_DNS="$ALB_DNS"
EOF
```

### Étape 8.3: Créer le Listener

```bash
source ~/devops-aws-ids.sh

# Créer le listener HTTP
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Listener ARN: $LISTENER_ARN"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export LISTENER_ARN="$LISTENER_ARN"
EOF

# Attendre un peu pour la propagation
sleep 30

# Tester l'ALB
echo ""
echo "Test de l'ALB:"
curl http://$ALB_DNS/api/health
echo ""
echo "✓ ALB configuré!"
echo "URL de l'API: http://$ALB_DNS/api"
```

---

## Partie 9: Frontend S3 + CloudFront (45 min)

### Étape 9.1: Créer le Bucket S3

```bash
source ~/devops-aws-ids.sh

# Générer un nom de bucket unique
BUCKET_SUFFIX=$(date +%s)
BUCKET_NAME="devops-todo-app-frontend-${BUCKET_SUFFIX}"

# Créer le bucket
aws s3 mb s3://$BUCKET_NAME --region eu-west-1

echo "Bucket créé: $BUCKET_NAME"

# Configurer le bucket pour l'hébergement web
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document error.html

# Configurer la politique du bucket pour l'accès public
cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF

# Désactiver le blocage des accès publics
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Appliquer la politique
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file:///tmp/bucket-policy.json

echo "Bucket configuré pour l'accès public"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export BUCKET_NAME="$BUCKET_NAME"
EOF
```

### Étape 9.2: Déployer le Frontend sur S3

```bash
source ~/devops-aws-ids.sh

# Aller dans le répertoire frontend
cd ~/devops-todo-app/app/frontend

# Remplacer l'URL de l'API dans config.js
sed -i "s|YOUR_ALB_DNS_HERE|${ALB_DNS}|g" config.js

# Vérifier le remplacement
echo "Vérification de la configuration:"
grep "baseURL" config.js

# Upload vers S3
aws s3 sync . s3://$BUCKET_NAME \
  --exclude ".git/*" \
  --exclude "*.md" \
  --delete

echo "✓ Frontend déployé sur S3"
echo "URL du site web: http://${BUCKET_NAME}.s3-website-eu-west-1.amazonaws.com"

# Tester l'accès
curl -I "http://${BUCKET_NAME}.s3-website-eu-west-1.amazonaws.com"
```

### Étape 9.4: Créer une Distribution CloudFront

```bash
source ~/devops-aws-ids.sh

# Créer la configuration CloudFront
cat > /tmp/cloudfront-config.json << EOF
{
  "CallerReference": "devops-todo-app-$(date +%s)",
  "Comment": "CloudFront distribution for DevOps Todo App",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-${BUCKET_NAME}",
        "DomainName": "${BUCKET_NAME}.s3-website-eu-west-1.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          }
        }
      }
    ]
  },
  "DefaultRootObject": "index.html",
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${BUCKET_NAME}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 3600,
    "MaxTTL": 86400,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "PriceClass": "PriceClass_100",
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
EOF

# Créer la distribution CloudFront
CLOUDFRONT_OUTPUT=$(aws cloudfront create-distribution \
  --distribution-config file:///tmp/cloudfront-config.json)

CLOUDFRONT_ID=$(echo $CLOUDFRONT_OUTPUT | jq -r '.Distribution.Id')
CLOUDFRONT_DOMAIN=$(echo $CLOUDFRONT_OUTPUT | jq -r '.Distribution.DomainName')

echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export CLOUDFRONT_ID="$CLOUDFRONT_ID"
export CLOUDFRONT_DOMAIN="$CLOUDFRONT_DOMAIN"
EOF

echo ""
echo "✓ CloudFront en cours de déploiement (cela prend 10-15 minutes)"
echo "URL finale: https://${CLOUDFRONT_DOMAIN}"
echo ""
echo "En attendant, vous pouvez accéder au site via S3:"
echo "http://${BUCKET_NAME}.s3-website-eu-west-1.amazonaws.com"
```

---

## Partie 10: Monitoring avec CloudWatch (30 min)

### Étape 10.1: Créer des Alarmes CloudWatch

```bash
source ~/devops-aws-ids.sh

# Créer un SNS Topic pour les notifications
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name devops-alerts \
  --query 'TopicArn' \
  --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# S'abonner au topic avec votre email
read -p "Entrez votre adresse e-mail pour les alertes: " EMAIL_ADDRESS

aws sns subscribe \
  --topic-arn $SNS_TOPIC_ARN \
  --protocol email \
  --notification-endpoint $EMAIL_ADDRESS

echo "✓ Vérifiez votre email et confirmez l'abonnement SNS"
echo "Appuyez sur Entrée après avoir confirmé..."
read

# Alarme CPU élevé sur EC2
aws cloudwatch put-metric-alarm \
  --alarm-name devops-ec2-high-cpu \
  --alarm-description "Alerte si le CPU dépasse 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --alarm-actions $SNS_TOPIC_ARN

echo "✓ Alarme CPU créée"

# Alarme connexions RDS élevées
aws cloudwatch put-metric-alarm \
  --alarm-name devops-rds-high-connections \
  --alarm-description "Alerte si trop de connexions à la base de données" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=DBInstanceIdentifier,Value=devops-postgres-db \
  --alarm-actions $SNS_TOPIC_ARN

echo "✓ Alarme RDS créée"

# Alarme Unhealthy Host sur le Target Group
aws cloudwatch put-metric-alarm \
  --alarm-name devops-alb-unhealthy-host \
  --alarm-description "Alerte si l'instance backend est unhealthy" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 \
  --dimensions Name=TargetGroup,Value=$(echo $TG_ARN | cut -d: -f6) \
               Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d: -f6 | cut -d/ -f2-4) \
  --alarm-actions $SNS_TOPIC_ARN

echo "✓ Alarme ALB créée"

# Sauvegarder
cat >> ~/devops-aws-ids.sh << EOF
export SNS_TOPIC_ARN="$SNS_TOPIC_ARN"
EOF
```

### Étape 10.2: Créer un Dashboard CloudWatch

```bash
source ~/devops-aws-ids.sh

# Créer le dashboard
cat > /tmp/dashboard-config.json << EOF
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
        "region": "eu-west-1",
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
        "region": "eu-west-1",
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
        "region": "eu-west-1",
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
        "region": "eu-west-1",
        "title": "Application Logs (Recent)",
        "stacked": false
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name devops-infrastructure-dashboard \
  --dashboard-body file:///tmp/dashboard-config.json

echo "✓ Dashboard CloudWatch créé"
echo "Accès: https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=devops-infrastructure-dashboard"
```

---

## Partie 11: Tests de l'Infrastructure (30 min)

### Étape 11.1: Tests Fonctionnels de l'API

```bash
source ~/devops-aws-ids.sh

echo "=== Tests de l'API DevOps Todo ==="
echo ""

# Test 1: Health Check
echo "Test 1: Health Check"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" http://$ALB_DNS/api/health)
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Health check réussi"
    echo "  Réponse: $BODY"
else
    echo "✗ Health check échoué (HTTP $HTTP_CODE)"
fi
echo ""

# Test 2: Créer une tâche
echo "Test 2: Créer une tâche"
CREATE_RESPONSE=$(curl -s -X POST http://$ALB_DNS/api/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test automatique",
    "description": "Tâche créée par le script de test",
    "completed": false
  }')

TODO_ID=$(echo $CREATE_RESPONSE | jq -r '.id')
if [ "$TODO_ID" != "null" ] && [ "$TODO_ID" != "" ]; then
    echo "✓ Tâche créée (ID: $TODO_ID)"
    echo "  Réponse: $CREATE_RESPONSE"
else
    echo "✗ Échec de la création de tâche"
fi
echo ""

# Test 3: Lister toutes les tâches
echo "Test 3: Lister toutes les tâches"
LIST_RESPONSE=$(curl -s http://$ALB_DNS/api/todos)
TODO_COUNT=$(echo $LIST_RESPONSE | jq '. | length')
echo "✓ Récupération de $TODO_COUNT tâche(s)"
echo ""

# Test 4: Récupérer une tâche spécifique
echo "Test 4: Récupérer une tâche spécifique (ID: $TODO_ID)"
GET_RESPONSE=$(curl -s -w "\n%{http_code}" http://$ALB_DNS/api/todos/$TODO_ID)
HTTP_CODE=$(echo "$GET_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Tâche récupérée"
else
    echo "✗ Échec de la récupération (HTTP $HTTP_CODE)"
fi
echo ""

# Test 5: Mettre à jour une tâche
echo "Test 5: Mettre à jour une tâche"
UPDATE_RESPONSE=$(curl -s -X PUT http://$ALB_DNS/api/todos/$TODO_ID \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test automatique (modifié)",
    "description": "Tâche mise à jour par le script de test",
    "completed": true
  }')
echo "✓ Tâche mise à jour"
echo "  Réponse: $UPDATE_RESPONSE"
echo ""

# Test 6: Supprimer une tâche
echo "Test 6: Supprimer une tâche"
DELETE_CODE=$(curl -s -w "%{http_code}" -X DELETE http://$ALB_DNS/api/todos/$TODO_ID -o /dev/null)
if [ "$DELETE_CODE" = "204" ]; then
    echo "✓ Tâche supprimée"
else
    echo "✗ Échec de la suppression (HTTP $DELETE_CODE)"
fi
echo ""

echo "=== Tests terminés ==="
```

### Étape 11.2: Tests de Charge avec Apache Bench

```bash
source ~/devops-aws-ids.sh

# Installer Apache Bench si nécessaire
if ! command -v ab &> /dev/null; then
    echo "Installation d'Apache Bench..."
    sudo dnf install -y httpd-tools
fi

echo "=== Tests de charge ==="
echo ""

# Test 1: Health Check (1000 requêtes, 10 concurrentes)
echo "Test 1: Health Check - 1000 requêtes, 10 concurrentes"
ab -n 1000 -c 10 http://$ALB_DNS/api/health

echo ""
echo "Test 2: GET /api/todos - 500 requêtes, 5 concurrentes"
ab -n 500 -c 5 http://$ALB_DNS/api/todos

echo ""
echo "=== Tests de charge terminés ==="
```

### Étape 11.3: Vérifier les Logs

```bash
source ~/devops-aws-ids.sh

# Vérifier les logs de l'application
echo "=== Logs de l'application (dernières 50 lignes) ==="
ssh -i ~/.ssh/devops-keypair.pem ec2-user@$INSTANCE_PUBLIC_IP \
  "cd /home/ec2-user/app/backend && docker-compose logs --tail=50"

echo ""
echo "=== Logs CloudWatch ==="
echo "Accès aux logs:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#logsV2:log-groups/log-group/\$252Faws\$252Fapplication\$252Fdevops-todo-app"
```

---

## Partie 12: Documentation et Scripts Utiles (20 min)

**Rendre les scripts exécutables:**

```bash
chmod +x scripts/deploy-backend.sh
chmod +x scripts/deploy-frontend.sh
chmod +x scripts/cleanup.sh
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

1. **CI/CD avec GitLab CI** (comme dans l'exemple précédent)
2. **HTTPS avec Let's Encrypt** sur l'ALB
3. **Auto Scaling Group** pour la haute disponibilité
4. **Backups automatisés** avec AWS Backup
5. **Tests de sécurité** avec Trivy/SonarQube
6. **Infrastructure as Code** migration vers Terraform/CloudFormation

**Bon exercice! 🚀**