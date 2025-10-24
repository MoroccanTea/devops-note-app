# DevOps Todo Application - Infrastructure AWS

Application de gestion de tâches déployée sur une infrastructure AWS complète.

## 📋 Architecture

```
    ┌─────────────────┐
    │   CloudFront    │ (CDN)
    └────────┬────────┘
             │
        ┌────▼─────┐
        │    S3    │ (Frontend statique)
        └──────────┘

  ┌──────────────────┐
  │   Utilisateurs   │
  └────────┬─────────┘
           │
      ┌────▼─────────┐
      │     ALB      │ (Load Balancer)
      └────┬─────────┘
           │
      ┌────▼─────────┐
      │EC2 (t2.micro)│ (Backend API Go + Docker)
      └────┬─────────┘
           │
      ┌────▼──────────┐
      │ RDS PostgreSQL│ (Base de données)
      └───────────────┘
```

### Composants de l'infrastructure

- **Frontend**: Application web statique (HTML/CSS/JS) sur S3 + CloudFront
- **Backend**: API REST en Go dockerisée sur EC2
- **Base de données**: PostgreSQL sur RDS (t3.micro)
- **Load Balancing**: Application Load Balancer
- **Réseau**: VPC personnalisé avec subnets publics et privés
- **Sécurité**: Security Groups, IAM Roles, Secrets Manager
- **Monitoring**: CloudWatch (alarmes, logs, dashboards)

## 🚀 Déploiement

### Prérequis

- Compte AWS (Free Tier)
- AWS CLI configuré
- Accès SSH

### Variables d'environnement

Charger les variables:
```bash
source ~/devops-aws-ids.sh
```

### Déploiement du backend

```bash
./scripts/deploy-backend.sh
```

### Déploiement du frontend

```bash
./scripts/deploy-frontend.sh
```

## 🧪 Tests

### Test de l'API

```bash
# Health check
curl http://$ALB_DNS/api/health

# Créer une tâche
curl -X POST http://$ALB_DNS/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Description","completed":false}'

# Lister les tâches
curl http://$ALB_DNS/api/todos
```

### Accès à l'application

- **Frontend (CloudFront)**: https://$CLOUDFRONT_DOMAIN
- **Frontend (S3)**: http://$BUCKET_NAME.s3-website-eu-west-1.amazonaws.com
- **API**: http://$ALB_DNS/api

## 📊 Monitoring

### Logs
- Application: `/aws/application/devops-todo-app`
- EC2: `/aws/ec2/devops-backend`

### Alarmes configurées
- CPU élevé sur EC2 (>80%)
- Connexions élevées sur RDS (>50)
- Instance backend unhealthy

## 🔒 Sécurité

- Credentials stockés dans AWS Secrets Manager
- Communication RDS via subnets privés uniquement
- HTTPS sur CloudFront
- Security Groups restrictifs
- IAM Roles avec principe du moindre privilège

## 💰 Coûts estimés (Free Tier)

- EC2 t2.micro: Gratuit (750h/mois)
- RDS t3.micro: Gratuit (750h/mois)
- S3: Gratuit (5 GB)
- CloudFront: Gratuit (50 GB sortant)
- ALB: ~$16/mois (non inclus dans Free Tier)

**Coût total estimé: ~$16-20/mois**

## 🧹 Nettoyage

Pour supprimer toute l'infrastructure:

```bash
./scripts/cleanup.sh
```

⚠️ **Attention**: Cette action est irréversible!

## 📝 API Endpoints

- `GET /api/health` - Health check
- `GET /api/todos` - Lister toutes les tâches
- `GET /api/todos/:id` - Récupérer une tâche
- `POST /api/todos` - Créer une tâche
- `PUT /api/todos/:id` - Mettre à jour une tâche
- `DELETE /api/todos/:id` - Supprimer une tâche

## 🛠️ Technologies utilisées

- **Backend**: Go 1.21, Gorilla Mux, PostgreSQL Driver
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla), Bootstrap 5
- **Infrastructure**: AWS (EC2, RDS, S3, CloudFront, ALB, VPC)
- **Conteneurisation**: Docker, Docker Compose
- **Monitoring**: CloudWatch
- **Sécurité**: Secrets Manager, IAM

## 📚 Documentation AWS

- [EC2](https://docs.aws.amazon.com/ec2/)
- [RDS](https://docs.aws.amazon.com/rds/)
- [S3](https://docs.aws.amazon.com/s3/)
- [CloudFront](https://docs.aws.amazon.com/cloudfront/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
