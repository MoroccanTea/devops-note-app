#!/bin/bash
# Script de déploiement du backend

set -e

# Charger les variables
source ~/devops-aws-ids.sh

echo "=== Déploiement du Backend DevOps Todo App ==="
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "app/backend/main.go" ]; then
    echo "Erreur: Exécutez ce script depuis la racine du projet"
    exit 1
fi

# Créer l'archive
echo "1. Création de l'archive..."
tar -czf /tmp/backend.tar.gz app/backend/

# Copier sur l'instance
echo "2. Upload vers l'instance EC2..."
scp -i ~/.ssh/devops-keypair.pem /tmp/backend.tar.gz ec2-user@$INSTANCE_PUBLIC_IP:/tmp/

# Déployer
echo "3. Déploiement sur l'instance..."
ssh -i ~/.ssh/devops-keypair.pem ec2-user@$INSTANCE_PUBLIC_IP << 'ENDSSH'
cd /home/ec2-user/app
tar -xzf /tmp/backend.tar.gz --strip-components=1
rm -f /tmp/backend.tar.gz

cd backend
docker-compose build
docker-compose down
docker-compose up -d

echo "Attente du démarrage..."
sleep 5

docker-compose ps
docker-compose logs --tail=20
ENDSSH

echo ""
echo "✓ Déploiement terminé!"
echo "Tester: curl http://$ALB_DNS/api/health"

# Nettoyer
rm -f /tmp/backend.tar.gz